import { describe, expect, it, vi } from 'vitest';
import {
  buildGatewayRunnerConfig,
  createBricksGatewayAdapter,
} from '../src/openclawGateway.js';

function makePlatformJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.signature`;
}

const token = makePlatformJwt({
  typ: 'platform_plugin',
  pluginId: 'plugin_local_main',
  userId: 'user_1',
  exp: Math.floor(Date.now() / 1000) + 3600,
});

describe('buildGatewayRunnerConfig', () => {
  it('builds runtime config from the OpenClaw-resolved account', () => {
    expect(
      buildGatewayRunnerConfig(
        {
          accountId: 'user_1',
          config: {
            BRICKS_BASE_URL: 'https://bricks.askman.dev/',
            BRICKS_PLUGIN_ID: 'plugin_local_main',
            BRICKS_PLATFORM_TOKEN: token,
          },
        },
        {
          OPENCLAW_PLUGIN_POLL_INTERVAL_MS: '5000',
          OPENCLAW_PLUGIN_DEFAULT_CURSOR: 'cur_7',
          OPENCLAW_PLUGIN_STATE_FILE: '/tmp/bricks-state.json',
          OPENCLAW_PLUGIN_ASSISTANT_NAME: 'Bricks Managed Runner',
        },
      ),
    ).toEqual({
      baseUrl: 'https://bricks.askman.dev/',
      token,
      pluginId: 'plugin_local_main',
      tokenUserId: 'user_1',
      pollIntervalMs: 5000,
      defaultCursor: 'cur_7',
      stateFilePath: '/tmp/bricks-state.json',
      assistantName: 'Bricks Managed Runner',
    });
  });
});

describe('createBricksGatewayAdapter', () => {
  it('starts the runner under the gateway abort signal', async () => {
    const runUntilAbort = vi.fn().mockResolvedValue(undefined);
    const createRunner = vi.fn(() => ({ runUntilAbort }));
    const setStatus = vi.fn();

    const adapter = createBricksGatewayAdapter({
      env: {
        OPENCLAW_PLUGIN_POLL_INTERVAL_MS: '2500',
      },
      createRunner,
    });

    const abortController = new AbortController();
    await adapter.startAccount({
      accountId: 'user_1',
      account: {
        accountId: 'user_1',
        config: {
          BRICKS_BASE_URL: 'https://bricks.askman.dev/',
          BRICKS_PLUGIN_ID: 'plugin_local_main',
          BRICKS_PLATFORM_TOKEN: token,
        },
      },
      abortSignal: abortController.signal,
      log: {
        info: vi.fn(),
      },
      getStatus: () => ({
        accountId: 'user_1',
        running: true,
      }),
      setStatus,
    });

    expect(createRunner).toHaveBeenCalledWith(
      expect.objectContaining({
        baseUrl: 'https://bricks.askman.dev/',
        pluginId: 'plugin_local_main',
        tokenUserId: 'user_1',
        pollIntervalMs: 2500,
      }),
      expect.objectContaining({
        info: expect.any(Function),
        warn: expect.any(Function),
        error: expect.any(Function),
      }),
    );
    expect(runUntilAbort).toHaveBeenCalledWith(abortController.signal);
    expect(setStatus).toHaveBeenCalledWith(
      expect.objectContaining({
        accountId: 'user_1',
        baseUrl: 'https://bricks.askman.dev/',
        tokenStatus: 'available',
        mode: 'pull',
        lastError: null,
      }),
    );
  });

  it('records a stop timestamp when the gateway stops the account', async () => {
    const setStatus = vi.fn();
    const adapter = createBricksGatewayAdapter({
      now: () => 1234,
    });

    await adapter.stopAccount({
      accountId: 'user_1',
      account: {
        accountId: 'user_1',
        config: {
          BRICKS_BASE_URL: 'https://bricks.askman.dev/',
          BRICKS_PLUGIN_ID: 'plugin_local_main',
          BRICKS_PLATFORM_TOKEN: token,
        },
      },
      abortSignal: new AbortController().signal,
      log: {
        info: vi.fn(),
      },
      getStatus: () => ({
        accountId: 'user_1',
        running: true,
      }),
      setStatus,
    });

    expect(setStatus).toHaveBeenCalledWith(
      expect.objectContaining({
        accountId: 'user_1',
        lastStopAt: 1234,
      }),
    );
  });

  it('captures startup failures in account status before rethrowing', async () => {
    const setStatus = vi.fn();
    const adapter = createBricksGatewayAdapter({
      createRunner: vi.fn(() => {
        throw new Error('runner init failed');
      }),
    });

    await expect(
      adapter.startAccount({
        accountId: 'user_1',
        account: {
          accountId: 'user_1',
          config: {
            BRICKS_BASE_URL: 'https://bricks.askman.dev/',
            BRICKS_PLUGIN_ID: 'plugin_local_main',
            BRICKS_PLATFORM_TOKEN: token,
          },
        },
        abortSignal: new AbortController().signal,
        log: {
          info: vi.fn(),
        },
        getStatus: () => ({
          accountId: 'user_1',
          running: false,
        }),
        setStatus,
      }),
    ).rejects.toThrow('runner init failed');

    expect(setStatus).toHaveBeenLastCalledWith(
      expect.objectContaining({
        accountId: 'user_1',
        lastError: expect.stringContaining('runner init failed'),
      }),
    );
  });
});
