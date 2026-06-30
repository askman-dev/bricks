import { execFile } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import { promisify } from 'util';
import type { RunnerConfig } from './config.js';
import type { RunRequest, RunResponse } from './types.js';

const execFileAsync = promisify(execFile);
const WORKSPACE_ROOT = '/workspace';
const HOME_ROOT = '/home/bricks';

export class SandboxRunnerError extends Error {
  constructor(message: string, public readonly statusCode = 400) {
    super(message);
    this.name = 'SandboxRunnerError';
  }
}

export function validateUserSegment(value: string): string {
  const trimmed = value.trim();
  if (!/^user-[a-f0-9]{16}$/.test(trimmed)) {
    throw new SandboxRunnerError('Invalid userSegment');
  }
  return trimmed;
}

export function validateContainerCwd(value: string): string {
  const normalized = path.posix.normalize(value.trim());
  if (!normalized.startsWith(`${WORKSPACE_ROOT}/`) && normalized !== WORKSPACE_ROOT) {
    throw new SandboxRunnerError('cwd must be inside /workspace');
  }
  if (normalized.includes('\0') || normalized.split('/').some((part) => part === '..')) {
    throw new SandboxRunnerError('Invalid cwd');
  }
  return normalized;
}

export function userSandboxRoot(config: RunnerConfig, userSegment: string): string {
  return path.join(config.sandboxRoot, userSegment);
}

export function userSandboxFsRoot(config: RunnerConfig, userSegment: string): string {
  return path.join(userSandboxRoot(config, userSegment), 'fs');
}

export function userSandboxHomeRoot(config: RunnerConfig, userSegment: string): string {
  return path.join(userSandboxRoot(config, userSegment), 'home');
}

export function containerName(config: RunnerConfig, userSegment: string): string {
  return `${config.containerPrefix}-${userSegment}`;
}

function truncateOutput(value: string, maxBytes: number): string {
  const buffer = Buffer.from(value);
  if (buffer.length <= maxBytes) return value;
  return `${buffer.subarray(0, maxBytes).toString('utf8')}\n[output truncated]`;
}

async function dockerJson(config: RunnerConfig, args: string[]): Promise<unknown | null> {
  try {
    const { stdout } = await execFileAsync(config.dockerBin, args, {
      timeout: 10_000,
      maxBuffer: config.maxOutputBytes,
    });
    return stdout.trim() ? JSON.parse(stdout) : null;
  } catch {
    return null;
  }
}

export async function ensureUserSandboxDirectories(config: RunnerConfig, userSegment: string): Promise<void> {
  const fsRoot = userSandboxFsRoot(config, userSegment);
  await fs.mkdir(path.join(fsRoot, 'channels'), { recursive: true });
  await fs.mkdir(path.join(fsRoot, 'shared'), { recursive: true });
  await fs.mkdir(path.join(fsRoot, 'tmp'), { recursive: true });
  await fs.mkdir(userSandboxHomeRoot(config, userSegment), { recursive: true });
  await fs.mkdir(path.join(userSandboxRoot(config, userSegment), 'meta'), { recursive: true });
}

export async function ensureUserContainer(config: RunnerConfig, userSegment: string): Promise<string> {
  await ensureUserSandboxDirectories(config, userSegment);
  const name = containerName(config, userSegment);
  const inspect = await dockerJson(config, ['inspect', name]);
  const existing = Array.isArray(inspect) ? inspect[0] as { State?: { Running?: boolean } } | undefined : undefined;
  if (existing?.State?.Running) {
    return name;
  }
  if (existing) {
    await execFileAsync(config.dockerBin, ['start', name], {
      timeout: 30_000,
      maxBuffer: config.maxOutputBytes,
    });
    return name;
  }

  await execFileAsync(
    config.dockerBin,
    [
      'run',
      '-d',
      '--name',
      name,
      '--runtime',
      config.runtime,
      '--workdir',
      WORKSPACE_ROOT,
      '--network',
      config.network,
      '--cap-drop',
      'ALL',
      '--security-opt',
      'no-new-privileges',
      '--env',
      `HOME=${HOME_ROOT}`,
      '--env',
      `BRICKS_SANDBOX_FS_ROOT=${WORKSPACE_ROOT}`,
      '--mount',
      `type=bind,source=${userSandboxFsRoot(config, userSegment)},target=${WORKSPACE_ROOT}`,
      '--mount',
      `type=bind,source=${userSandboxHomeRoot(config, userSegment)},target=${HOME_ROOT}`,
      config.image,
      'sleep',
      'infinity',
    ],
    {
      timeout: 30_000,
      maxBuffer: config.maxOutputBytes,
    },
  );
  return name;
}

export async function runSandboxCommand(config: RunnerConfig, request: RunRequest): Promise<RunResponse> {
  const userSegment = validateUserSegment(request.userSegment);
  const cwd = validateContainerCwd(request.cwd);
  const command = request.command.trim();
  if (!command) {
    throw new SandboxRunnerError('command is required');
  }
  const maxBuffer = Math.min(request.maxBufferBytes ?? config.maxOutputBytes, config.maxOutputBytes * 4);
  const timeout = Math.min(request.timeoutMs ?? config.defaultTimeoutMs, config.defaultTimeoutMs * 4);
  const name = await ensureUserContainer(config, userSegment);

  try {
    const { stdout, stderr } = await execFileAsync(
      config.dockerBin,
      ['exec', '--workdir', cwd, name, '/bin/bash', '-lc', command],
      { timeout, maxBuffer },
    );
    return {
      stdout: truncateOutput(stdout, config.maxOutputBytes),
      stderr: truncateOutput(stderr, config.maxOutputBytes),
      exitCode: 0,
    };
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: truncateOutput(err.stdout ?? '', config.maxOutputBytes),
      stderr: truncateOutput(err.stderr ?? err.message, config.maxOutputBytes),
      exitCode: typeof err.code === 'number' ? err.code : 1,
    };
  }
}
