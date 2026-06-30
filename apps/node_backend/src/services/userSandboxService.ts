import crypto from 'crypto';
import { execFile } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

const DEFAULT_SANDBOX_ROOT = path.resolve(process.cwd(), '.bricks-data', 'sandboxes');
const DEFAULT_SANDBOX_IMAGE = 'node:22-bookworm';
const DEFAULT_SANDBOX_NETWORK = 'bridge';
const DEFAULT_SANDBOX_RUNTIME = 'runsc';
const SANDBOX_WORKSPACE_ROOT = '/workspace';
const SANDBOX_HOME = '/home/bricks';
const MAX_SANDBOX_OUTPUT_BYTES = 256 * 1024;

export type SandboxRunnerKind = 'docker' | 'http' | 'local';

export interface SandboxCommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export interface RunInUserSandboxInput {
  userId: string;
  hostCwd: string;
  containerCwd: string;
  command: string;
  timeoutMs?: number;
  maxBufferBytes?: number;
}

export function opaqueSandboxSegment(prefix: string, value: string): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed.includes('\0')) {
    throw new Error(`Invalid ${prefix} identifier`);
  }
  const hash = crypto.createHash('sha256').update(trimmed).digest('hex').slice(0, 16);
  return `${prefix}-${hash}`;
}

export function getSandboxRoot(): string {
  return path.resolve(process.env.BRICKS_SANDBOX_ROOT || DEFAULT_SANDBOX_ROOT);
}

export function userSandboxRoot(userId: string): string {
  return path.join(getSandboxRoot(), opaqueSandboxSegment('user', userId));
}

export function userSandboxFsRoot(userId: string): string {
  return path.join(userSandboxRoot(userId), 'fs');
}

export function userSandboxMetaRoot(userId: string): string {
  return path.join(userSandboxRoot(userId), 'meta');
}

export function userSandboxHomeRoot(userId: string): string {
  return path.join(userSandboxRoot(userId), 'home');
}

export function userSandboxChannelDirectory(userId: string, channelId: string): string {
  return path.join(
    userSandboxFsRoot(userId),
    'channels',
    opaqueSandboxSegment('channel', channelId),
  );
}

export function sandboxChannelContainerPath(channelId: string): string {
  return path.posix.join(
    SANDBOX_WORKSPACE_ROOT,
    'channels',
    opaqueSandboxSegment('channel', channelId),
  );
}

export function sandboxWorkspaceContainerPath(channelId: string): string {
  return path.posix.join(sandboxChannelContainerPath(channelId), 'workspace');
}

export async function ensureUserSandbox(userId: string): Promise<void> {
  await fs.mkdir(path.join(userSandboxFsRoot(userId), 'channels'), { recursive: true });
  await fs.mkdir(path.join(userSandboxFsRoot(userId), 'shared'), { recursive: true });
  await fs.mkdir(path.join(userSandboxFsRoot(userId), 'tmp'), { recursive: true });
  await fs.mkdir(userSandboxHomeRoot(userId), { recursive: true });
  await fs.mkdir(path.join(userSandboxMetaRoot(userId), 'snapshots'), { recursive: true });
}

function sandboxRunnerKind(): SandboxRunnerKind {
  const configured = process.env.BRICKS_SANDBOX_RUNNER?.trim().toLowerCase();
  if (configured === 'docker' || configured === 'http' || configured === 'local') {
    if (configured === 'local' && process.env.NODE_ENV === 'production') {
      throw new Error('BRICKS_SANDBOX_RUNNER=local is not allowed in production');
    }
    return configured;
  }
  return process.env.NODE_ENV === 'production' ? 'http' : 'local';
}

function dockerContainerName(userId: string): string {
  return `bricks-${opaqueSandboxSegment('user', userId)}`;
}

function dockerImage(): string {
  return process.env.BRICKS_SANDBOX_IMAGE?.trim() || DEFAULT_SANDBOX_IMAGE;
}

function dockerNetwork(): string {
  return process.env.BRICKS_SANDBOX_NETWORK?.trim() || DEFAULT_SANDBOX_NETWORK;
}

function dockerRuntime(): string {
  return process.env.BRICKS_SANDBOX_DOCKER_RUNTIME?.trim() || DEFAULT_SANDBOX_RUNTIME;
}

function httpRunnerUrl(): string {
  const value = process.env.BRICKS_SANDBOX_RUNNER_URL?.trim();
  if (!value) throw new Error('BRICKS_SANDBOX_RUNNER_URL is required for http sandbox runner');
  return value.replace(/\/+$/, '');
}

function httpRunnerToken(): string | null {
  return process.env.BRICKS_SANDBOX_RUNNER_TOKEN?.trim() || null;
}

function truncateOutput(value: string, maxBytes: number): string {
  const buffer = Buffer.from(value);
  if (buffer.length <= maxBytes) return value;
  return `${buffer.subarray(0, maxBytes).toString('utf8')}\n[output truncated]`;
}

async function inspectDockerContainer(containerName: string): Promise<{ exists: boolean; running: boolean }> {
  try {
    const { stdout } = await execFileAsync('docker', ['inspect', containerName], {
      timeout: 10_000,
      maxBuffer: MAX_SANDBOX_OUTPUT_BYTES,
    });
    const parsed = JSON.parse(stdout) as Array<{ State?: { Running?: boolean } }>;
    return { exists: parsed.length > 0, running: Boolean(parsed[0]?.State?.Running) };
  } catch {
    return { exists: false, running: false };
  }
}

async function ensureDockerSandbox(userId: string): Promise<string> {
  await ensureUserSandbox(userId);
  const containerName = dockerContainerName(userId);
  const existing = await inspectDockerContainer(containerName);
  if (existing.running) {
    return containerName;
  }
  if (existing.exists) {
    await execFileAsync('docker', ['start', containerName], {
      timeout: 30_000,
      maxBuffer: MAX_SANDBOX_OUTPUT_BYTES,
    });
    return containerName;
  }

  await execFileAsync(
    'docker',
    [
      'run',
      '-d',
      '--name',
      containerName,
      '--runtime',
      dockerRuntime(),
      '--workdir',
      SANDBOX_WORKSPACE_ROOT,
      '--network',
      dockerNetwork(),
      '--cap-drop',
      'ALL',
      '--security-opt',
      'no-new-privileges',
      '--env',
      `HOME=${SANDBOX_HOME}`,
      '--env',
      `BRICKS_SANDBOX_FS_ROOT=${SANDBOX_WORKSPACE_ROOT}`,
      '--mount',
      `type=bind,source=${userSandboxFsRoot(userId)},target=${SANDBOX_WORKSPACE_ROOT}`,
      '--mount',
      `type=bind,source=${userSandboxHomeRoot(userId)},target=${SANDBOX_HOME}`,
      dockerImage(),
      'sleep',
      'infinity',
    ],
    {
      timeout: 30_000,
      maxBuffer: MAX_SANDBOX_OUTPUT_BYTES,
    },
  );
  return containerName;
}

async function runLocalSandboxCommand(input: RunInUserSandboxInput): Promise<SandboxCommandResult> {
  await ensureUserSandbox(input.userId);
  try {
    const result = await execFileAsync('/bin/bash', ['-lc', input.command], {
      cwd: input.hostCwd,
      timeout: input.timeoutMs ?? 120_000,
      maxBuffer: input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES,
      env: {
        ...process.env,
        HOME: userSandboxHomeRoot(input.userId),
        BRICKS_SANDBOX_ROOT: userSandboxRoot(input.userId),
        BRICKS_SANDBOX_FS_ROOT: userSandboxFsRoot(input.userId),
      },
    });
    return {
      stdout: truncateOutput(result.stdout, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      stderr: truncateOutput(result.stderr, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      exitCode: 0,
    };
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: truncateOutput(err.stdout ?? '', input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      stderr: truncateOutput(err.stderr ?? err.message, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      exitCode: typeof err.code === 'number' ? err.code : 1,
    };
  }
}

async function runDockerSandboxCommand(input: RunInUserSandboxInput): Promise<SandboxCommandResult> {
  const containerName = await ensureDockerSandbox(input.userId);
  try {
    const result = await execFileAsync(
      'docker',
      ['exec', '--workdir', input.containerCwd, containerName, '/bin/bash', '-lc', input.command],
      {
        timeout: input.timeoutMs ?? 120_000,
        maxBuffer: input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES,
      },
    );
    return {
      stdout: truncateOutput(result.stdout, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      stderr: truncateOutput(result.stderr, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      exitCode: 0,
    };
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: truncateOutput(err.stdout ?? '', input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      stderr: truncateOutput(err.stderr ?? err.message, input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
      exitCode: typeof err.code === 'number' ? err.code : 1,
    };
  }
}

async function runHttpSandboxCommand(input: RunInUserSandboxInput): Promise<SandboxCommandResult> {
  await ensureUserSandbox(input.userId);
  const token = httpRunnerToken();
  const response = await fetch(`${httpRunnerUrl()}/v1/run`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({
      userSegment: opaqueSandboxSegment('user', input.userId),
      cwd: input.containerCwd,
      command: input.command,
      timeoutMs: input.timeoutMs ?? 120_000,
      maxBufferBytes: input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES,
    }),
  });

  if (!response.ok) {
    return {
      stdout: '',
      stderr: `Sandbox runner request failed with HTTP ${response.status}`,
      exitCode: 1,
    };
  }

  const body = await response.json() as Partial<SandboxCommandResult>;
  return {
    stdout: truncateOutput(String(body.stdout ?? ''), input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
    stderr: truncateOutput(String(body.stderr ?? ''), input.maxBufferBytes ?? MAX_SANDBOX_OUTPUT_BYTES),
    exitCode: typeof body.exitCode === 'number' ? body.exitCode : 1,
  };
}

export async function runInUserSandbox(input: RunInUserSandboxInput): Promise<SandboxCommandResult> {
  if (!input.command.trim()) {
    throw new Error('command is required');
  }

  const runner = sandboxRunnerKind();
  if (runner === 'docker') {
    return runDockerSandboxCommand(input);
  }
  if (runner === 'http') {
    return runHttpSandboxCommand(input);
  }

  return runLocalSandboxCommand(input);
}
