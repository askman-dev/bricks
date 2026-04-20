import { describe, expect, it, vi } from 'vitest';
import pluginEntry, {
  BRICKS_CHANNEL_CONFIG_SCHEMA,
  CHANNEL_ID,
  DEFAULT_ACCOUNT_ID,
  bricksChannelPlugin,
} from '../src/openclawExtension.js';

function makePlatformJwt(payload: Record<string, unknown>): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  return `${header}.${body}.signature`;
}

describe('openclawExtension channel entry', () => {
  it('reuses the Bricks channel config schema', () => {
    expect(pluginEntry.configSchema).toEqual(BRICKS_CHANNEL_CONFIG_SCHEMA);
    expect(pluginEntry.configSchema.schema).toMatchObject({
      additionalProperties: false,
    });
    expect(pluginEntry.configSchema.schema).not.toHaveProperty('required');
  });

  it('registers the Bricks channel plugin outside cli-metadata mode', () => {
    const registerChannel = vi.fn();

    pluginEntry.register({ registrationMode: 'full', registerChannel });

    expect(registerChannel).toHaveBeenCalledWith({ plugin: bricksChannelPlugin });
  });

  it('skips channel registration in cli-metadata mode', () => {
    const registerChannel = vi.fn();

    pluginEntry.register({ registrationMode: 'cli-metadata', registerChannel });

    expect(registerChannel).not.toHaveBeenCalled();
  });

  it('exposes a gateway adapter for OpenClaw-managed lifecycle', () => {
    expect(bricksChannelPlugin.gateway).toEqual({
      startAccount: expect.any(Function),
      stopAccount: expect.any(Function),
    });
  });
});

describe('bricksChannelPlugin setup', () => {
  it('writes channel config into channels.dev-askman-bricks', () => {
    const cfg = bricksChannelPlugin.setup.applyAccountConfig({
      cfg: {},
      accountId: DEFAULT_ACCOUNT_ID,
      input: {
        BRICKS_BASE_URL: '  https://api.example.com  ',
        BRICKS_PLUGIN_ID: '  plugin-id  ',
        BRICKS_PLATFORM_TOKEN: '  jwt-token  ',
      },
    });

    expect(cfg.channels?.[CHANNEL_ID]).toEqual({
      BRICKS_BASE_URL: 'https://api.example.com',
      BRICKS_PLUGIN_ID: 'plugin-id',
      BRICKS_PLATFORM_TOKEN: 'jwt-token',
    });
  });

  it('preserves stored values when re-validating partial updates', () => {
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://stored.example.com',
          BRICKS_PLUGIN_ID: 'stored-plugin',
          BRICKS_PLATFORM_TOKEN: 'stored-token',
        },
      },
    };

    const validationError = bricksChannelPlugin.setup.validateInput?.({
      cfg,
      accountId: DEFAULT_ACCOUNT_ID,
      input: {
        BRICKS_BASE_URL: 'https://updated.example.com',
      },
    });

    expect(validationError).toBeNull();
  });

  it('requires missing BRICKS_* values when neither input nor stored config provides them', () => {
    const validationError = bricksChannelPlugin.setup.validateInput?.({
      cfg: {},
      accountId: DEFAULT_ACCOUNT_ID,
      input: {},
    });

    expect(validationError).toBe('BRICKS_BASE_URL is required');
  });
});

describe('bricksChannelPlugin config and wizard', () => {
  it('reports configured state from stored channel config', async () => {
    const token = makePlatformJwt({
      typ: 'platform_plugin',
      pluginId: 'plugin-id',
      userId: 'user_1',
      exp: Math.floor(Date.now() / 1000) + 3600,
    });
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://api.example.com',
          BRICKS_PLUGIN_ID: 'plugin-id',
          BRICKS_PLATFORM_TOKEN: token,
        },
      },
    };

    expect(bricksChannelPlugin.config.listAccountIds(cfg)).toEqual(['user_1']);
    expect(bricksChannelPlugin.config.defaultAccountId?.(cfg)).toBe('user_1');
    expect(bricksChannelPlugin.config.resolveAccount(cfg).accountId).toBe('user_1');
    expect(bricksChannelPlugin.config.resolveAccount(cfg).configured).toBe(true);
    expect(await bricksChannelPlugin.setupWizard.status.resolveConfigured({ cfg })).toBe(true);
  });

  it('describes accounts safely without inventing a default account id', () => {
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://api.example.com',
          BRICKS_PLUGIN_ID: 'plugin-id',
          BRICKS_PLATFORM_TOKEN: 'jwt-token',
        },
      },
    };

    expect(
      bricksChannelPlugin.config.describeAccount?.(
        {
          enabled: true,
        } as never,
        cfg,
      ),
    ).toEqual({
      enabled: true,
      configured: false,
      extra: {
        baseUrl: 'https://api.example.com',
        pluginId: 'plugin-id',
        warning: expect.stringContaining('Invalid Bricks platform token'),
      },
    });
  });

  it('marks partial accounts as unconfigured when required config is missing', () => {
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://api.example.com',
          BRICKS_PLATFORM_TOKEN: 'jwt-token',
        },
      },
    };

    expect(
      bricksChannelPlugin.config.describeAccount?.(
        {
          enabled: true,
          configured: true,
        } as never,
        cfg,
      ),
    ).toEqual({
      enabled: true,
      configured: false,
      extra: {
        baseUrl: 'https://api.example.com',
        pluginId: null,
        warning: 'Missing required Bricks config: BRICKS_PLUGIN_ID',
      },
    });
  });

  it('throws when stored token config cannot derive a real account id', () => {
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://api.example.com',
          BRICKS_PLUGIN_ID: 'plugin-id',
          BRICKS_PLATFORM_TOKEN: 'not-a-jwt',
        },
      },
    };

    expect(() => bricksChannelPlugin.config.listAccountIds(cfg)).toThrow(
      'Invalid Bricks platform token config: BRICKS_PLATFORM_TOKEN must be a JWT with 3 segments',
    );
    expect(() => bricksChannelPlugin.config.defaultAccountId?.(cfg)).toThrow(
      'Invalid Bricks platform token config: BRICKS_PLATFORM_TOKEN must be a JWT with 3 segments',
    );
    expect(() => bricksChannelPlugin.config.resolveAccount(cfg)).toThrow(
      'Invalid Bricks platform token config: BRICKS_PLATFORM_TOKEN must be a JWT with 3 segments',
    );
  });

  it('stores wizard text and credential fields through channel config helpers', async () => {
    const afterBaseUrl = await bricksChannelPlugin.setupWizard.textInputs?.[0].applySet?.({
      cfg: {},
      accountId: DEFAULT_ACCOUNT_ID,
      credentialValues: {},
      value: ' https://api.example.com ',
    });

    const afterPluginId = await bricksChannelPlugin.setupWizard.textInputs?.[1].applySet?.({
      cfg: afterBaseUrl ?? {},
      accountId: DEFAULT_ACCOUNT_ID,
      credentialValues: {},
      value: ' dev-askman-bricks ',
    });

    const afterToken = await bricksChannelPlugin.setupWizard.credentials[0].applySet?.({
      cfg: afterPluginId ?? {},
      accountId: DEFAULT_ACCOUNT_ID,
      credentialValues: {},
      value: 'jwt-token',
      resolvedValue: ' jwt-token ',
    });

    expect(afterToken?.channels?.[CHANNEL_ID]).toEqual({
      BRICKS_BASE_URL: 'https://api.example.com',
      BRICKS_PLUGIN_ID: 'dev-askman-bricks',
      BRICKS_PLATFORM_TOKEN: 'jwt-token',
    });
  });
});
