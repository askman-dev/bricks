import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { RunnerConfig } from './config.js';

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

function config(root: string): RunnerConfig {
  return {
    host: '127.0.0.1',
    port: 8787,
    token: null,
    sandboxRoot: root,
    dockerBin: 'docker',
    runtime: 'runsc',
    image: 'node:22-bookworm',
    network: 'bridge',
    containerPrefix: 'bricks-sandbox',
    maxOutputBytes: 64 * 1024,
    defaultTimeoutMs: 120_000,
  };
}

describe('sandboxRunner', () => {
  beforeEach(() => {
    execFileAsyncMock.mockReset();
  });

  it('rejects invalid user segments and cwd escapes', async () => {
    const { validateContainerCwd, validateUserSegment } = await import('./sandboxRunner.js');

    expect(() => validateUserSegment('user-xyz')).toThrow(/Invalid userSegment/);
    expect(() => validateContainerCwd('/etc')).toThrow(/inside \/workspace/);
    expect(() => validateContainerCwd('/workspace/../etc')).toThrow(/inside \/workspace|Invalid cwd/);
    expect(validateContainerCwd('/workspace/channels/channel-abc/workspace')).toBe(
      '/workspace/channels/channel-abc/workspace',
    );
  });

  it('creates a runsc container with only one user filesystem mounted', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-runner-test-'));
    const { ensureUserContainer } = await import('./sandboxRunner.js');
    execFileAsyncMock.mockResolvedValueOnce({ stdout: '', stderr: '' });
    execFileAsyncMock.mockResolvedValueOnce({ stdout: 'container-id\n', stderr: '' });

    await ensureUserContainer(config(root), 'user-0123456789abcdef');

    const runCall = execFileAsyncMock.mock.calls[1];
    expect(runCall[0]).toBe('docker');
    expect(runCall[1]).toEqual(expect.arrayContaining(['--runtime', 'runsc']));
    expect(runCall[1]).toEqual(
      expect.arrayContaining([
        `type=bind,source=${path.join(root, 'user-0123456789abcdef', 'fs')},target=/workspace`,
      ]),
    );
    expect(runCall[1].join(' ')).not.toContain(path.join(root, 'user-other'));
    await fs.rm(root, { recursive: true, force: true });
  });

  it('starts an existing stopped container before returning it', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-runner-test-'));
    const { ensureUserContainer } = await import('./sandboxRunner.js');
    execFileAsyncMock.mockResolvedValueOnce({
      stdout: JSON.stringify([{ State: { Running: false } }]),
      stderr: '',
    });
    execFileAsyncMock.mockResolvedValueOnce({ stdout: 'started\n', stderr: '' });

    await ensureUserContainer(config(root), 'user-0123456789abcdef');

    expect(execFileAsyncMock.mock.calls[1][1]).toEqual([
      'start',
      'bricks-sandbox-user-0123456789abcdef',
    ]);
    await fs.rm(root, { recursive: true, force: true });
  });

  it('executes commands inside the requested workspace cwd', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'bricks-runner-test-'));
    const { runSandboxCommand } = await import('./sandboxRunner.js');
    execFileAsyncMock
      .mockResolvedValueOnce({
        stdout: JSON.stringify([{ State: { Running: true } }]),
        stderr: '',
      })
      .mockResolvedValueOnce({ stdout: 'ok\n', stderr: '' });

    const result = await runSandboxCommand(config(root), {
      userSegment: 'user-0123456789abcdef',
      cwd: '/workspace/channels/channel-abc/workspace',
      command: 'pwd',
    });

    expect(result.exitCode).toBe(0);
    expect(execFileAsyncMock.mock.calls[1][1]).toEqual([
      'exec',
      '--workdir',
      '/workspace/channels/channel-abc/workspace',
      'bricks-sandbox-user-0123456789abcdef',
      '/bin/bash',
      '-lc',
      'pwd',
    ]);
    await fs.rm(root, { recursive: true, force: true });
  });
});
