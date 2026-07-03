import { describe, expect, it, vi } from 'vitest';
import type { RunnerConfig } from './config.js';

const runSandboxCommandMock = vi.hoisted(() => vi.fn());

vi.mock('./sandboxRunner.js', async () => {
  const actual = await vi.importActual<typeof import('./sandboxRunner.js')>('./sandboxRunner.js');
  return {
    ...actual,
    runSandboxCommand: runSandboxCommandMock,
  };
});

function config(): RunnerConfig {
  return {
    host: '127.0.0.1',
    port: 0,
    token: 'secret',
    sandboxRoot: '/srv/bricks/sandboxes',
    dockerBin: 'docker',
    runtime: 'runsc',
    image: 'node:22-bookworm',
    network: 'bridge',
    containerPrefix: 'bricks-sandbox',
    maxOutputBytes: 64 * 1024,
    defaultTimeoutMs: 120_000,
  };
}

describe('server', () => {
  it('requires bearer auth for run requests', async () => {
    const { createServer } = await import('./server.js');
    const server = createServer(config());
    const response = await new Promise<Response>((resolve) => {
      server.listen(0, '127.0.0.1', async () => {
        const address = server.address();
        if (!address || typeof address === 'string') throw new Error('missing address');
        resolve(await fetch(`http://127.0.0.1:${address.port}/v1/run`, { method: 'POST' }));
        server.close();
      });
    });

    expect(response.status).toBe(401);
  });

  it('passes validated run body to sandbox runner', async () => {
    runSandboxCommandMock.mockResolvedValue({ stdout: 'ok', stderr: '', exitCode: 0 });
    const { createServer } = await import('./server.js');
    const server = createServer(config());
    const response = await new Promise<Response>((resolve) => {
      server.listen(0, '127.0.0.1', async () => {
        const address = server.address();
        if (!address || typeof address === 'string') throw new Error('missing address');
        resolve(await fetch(`http://127.0.0.1:${address.port}/v1/run`, {
          method: 'POST',
          headers: {
            Authorization: 'Bearer secret',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            userSegment: 'user-0123456789abcdef',
            cwd: '/workspace/shared',
            command: 'echo ok',
          }),
        }));
        server.close();
      });
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ stdout: 'ok', stderr: '', exitCode: 0 });
    expect(runSandboxCommandMock).toHaveBeenCalledWith(
      expect.any(Object),
      expect.objectContaining({
        userSegment: 'user-0123456789abcdef',
        cwd: '/workspace/shared',
        command: 'echo ok',
      }),
    );
  });
});
