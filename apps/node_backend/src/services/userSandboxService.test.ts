import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const execFileAsyncMock = vi.hoisted(() => vi.fn());
const execFileMock = vi.hoisted(() => vi.fn());

vi.mock('child_process', () => ({ execFile: execFileMock }));
vi.mock('util', async () => {
  const original = await vi.importActual<typeof import('util')>('util');
  return {
    ...original,
    promisify: (fn: unknown) => (fn === execFileMock ? execFileAsyncMock : original.promisify(fn as never)),
  };
});

describe('userSandboxService', () => {
  let tempDir: string;
  let previousRoot: string | undefined;
  let previousRunner: string | undefined;
  let previousRunnerUrl: string | undefined;
  let previousRunnerRootSegments: string | undefined;
  let previousNodeEnv: string | undefined;

  beforeEach(async () => {
    previousRoot = process.env.BRICKS_SANDBOX_ROOT;
    previousRunner = process.env.BRICKS_SANDBOX_RUNNER;
    previousRunnerUrl = process.env.BRICKS_SANDBOX_RUNNER_URL;
    previousRunnerRootSegments = process.env.BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS;
    previousNodeEnv = process.env.NODE_ENV;
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-user-sandbox-'));
    process.env.BRICKS_SANDBOX_ROOT = tempDir;
    process.env.BRICKS_SANDBOX_RUNNER = 'local';
    process.env.NODE_ENV = 'test';
    execFileAsyncMock.mockReset();
  });

  afterEach(async () => {
    if (previousRoot === undefined) {
      delete process.env.BRICKS_SANDBOX_ROOT;
    } else {
      process.env.BRICKS_SANDBOX_ROOT = previousRoot;
    }
    if (previousRunner === undefined) {
      delete process.env.BRICKS_SANDBOX_RUNNER;
    } else {
      process.env.BRICKS_SANDBOX_RUNNER = previousRunner;
    }
    if (previousRunnerUrl === undefined) {
      delete process.env.BRICKS_SANDBOX_RUNNER_URL;
    } else {
      process.env.BRICKS_SANDBOX_RUNNER_URL = previousRunnerUrl;
    }
    if (previousRunnerRootSegments === undefined) {
      delete process.env.BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS;
    } else {
      process.env.BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS = previousRunnerRootSegments;
    }
    if (previousNodeEnv === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = previousNodeEnv;
    }
    vi.unstubAllGlobals();
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('creates persistent per-user sandbox directories', async () => {
    const {
      ensureUserSandbox,
      userSandboxFsRoot,
      userSandboxHomeRoot,
      userSandboxMetaRoot,
    } = await import('./userSandboxService.js');

    await ensureUserSandbox('user-1');

    await expect(fs.stat(path.join(userSandboxFsRoot('user-1'), 'channels'))).resolves.toBeTruthy();
    await expect(fs.stat(path.join(userSandboxFsRoot('user-1'), 'shared'))).resolves.toBeTruthy();
    await expect(fs.stat(userSandboxHomeRoot('user-1'))).resolves.toBeTruthy();
    await expect(fs.stat(path.join(userSandboxMetaRoot('user-1'), 'snapshots'))).resolves.toBeTruthy();
  });

  it('runs local fallback commands with sandbox HOME and fs root env', async () => {
    const { ensureUserSandbox, runInUserSandbox, userSandboxFsRoot } = await import(
      './userSandboxService.js'
    );
    execFileAsyncMock.mockResolvedValueOnce({
      stdout: `${path.join(tempDir, 'user-abc', 'home')}|${path.join(tempDir, 'user-abc', 'fs')}`,
      stderr: '',
    });

    await ensureUserSandbox('user-1');
    const cwd = path.join(userSandboxFsRoot('user-1'), 'shared');
    const result = await runInUserSandbox({
      userId: 'user-1',
      hostCwd: cwd,
      containerCwd: '/workspace/shared',
      command: 'printf "$HOME|$BRICKS_SANDBOX_FS_ROOT"',
    });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('user-');
    expect(result.stdout).toContain('/fs');
  });

  it('delegates http runner commands using container cwd only', async () => {
    const fetchMock = vi.fn(async () => new Response(
      JSON.stringify({ stdout: 'ok', stderr: '', exitCode: 0 }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    ));
    vi.stubGlobal('fetch', fetchMock);
    process.env.BRICKS_SANDBOX_RUNNER = 'http';
    process.env.BRICKS_SANDBOX_RUNNER_URL = 'https://sandbox-runner.test/';
    process.env.BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS = 'production,sandboxes';

    const { runInUserSandbox, userSandboxFsRoot } = await import('./userSandboxService.js');
    const result = await runInUserSandbox({
      userId: 'user-1',
      hostCwd: path.join(userSandboxFsRoot('user-1'), 'shared'),
      containerCwd: '/workspace/shared',
      command: 'pwd',
    });

    expect(result).toEqual({ stdout: 'ok', stderr: '', exitCode: 0 });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://sandbox-runner.test/v1/run',
      expect.objectContaining({
        method: 'POST',
        body: expect.stringContaining('"cwd":"/workspace/shared"'),
      }),
    );
    const [, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(String(init.body)).not.toContain(tempDir);
    expect(JSON.parse(String(init.body))).toEqual(expect.objectContaining({
      sandboxRootSegments: ['production', 'sandboxes'],
    }));
  });

  it('rejects local runner in production', async () => {
    process.env.NODE_ENV = 'production';
    process.env.BRICKS_SANDBOX_RUNNER = 'local';
    const { runInUserSandbox, userSandboxFsRoot } = await import('./userSandboxService.js');

    await expect(runInUserSandbox({
      userId: 'user-1',
      hostCwd: path.join(userSandboxFsRoot('user-1'), 'shared'),
      containerCwd: '/workspace/shared',
      command: 'pwd',
    })).rejects.toThrow(/not allowed in production/);
  });

  it('docker runner starts stopped containers and uses runsc runtime for new containers', async () => {
    process.env.BRICKS_SANDBOX_RUNNER = 'docker';
    process.env.BRICKS_SANDBOX_DOCKER_RUNTIME = 'runsc';
    const { runInUserSandbox, userSandboxFsRoot } = await import('./userSandboxService.js');

    execFileAsyncMock
      .mockResolvedValueOnce({
        stdout: JSON.stringify([{ State: { Running: false } }]),
        stderr: '',
      })
      .mockResolvedValueOnce({ stdout: 'started\n', stderr: '' })
      .mockResolvedValueOnce({ stdout: 'ok\n', stderr: '' });

    await runInUserSandbox({
      userId: 'user-1',
      hostCwd: path.join(userSandboxFsRoot('user-1'), 'shared'),
      containerCwd: '/workspace/shared',
      command: 'echo ok',
    });

    expect(execFileAsyncMock.mock.calls[1][1]).toEqual([
      'start',
      expect.stringMatching(/^bricks-user-[a-f0-9]{16}$/),
    ]);

    execFileAsyncMock.mockReset();
    execFileAsyncMock
      .mockResolvedValueOnce({ stdout: '', stderr: '' })
      .mockResolvedValueOnce({ stdout: 'container-id\n', stderr: '' })
      .mockResolvedValueOnce({ stdout: 'ok\n', stderr: '' });

    await runInUserSandbox({
      userId: 'user-2',
      hostCwd: path.join(userSandboxFsRoot('user-2'), 'shared'),
      containerCwd: '/workspace/shared',
      command: 'echo ok',
    });

    expect(execFileAsyncMock.mock.calls[1][1]).toEqual(expect.arrayContaining(['--runtime', 'runsc']));
  });
});
