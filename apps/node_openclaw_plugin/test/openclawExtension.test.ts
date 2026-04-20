import { describe, expect, it, vi } from 'vitest';
import pluginEntry, {
  BRICKS_CHANNEL_CONFIG_SCHEMA,
  CHANNEL_ID,
  DEFAULT_ACCOUNT_ID,
  bricksChannelPlugin,
} from '../src/openclawExtension.js';

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
    const cfg = {
      channels: {
        [CHANNEL_ID]: {
          BRICKS_BASE_URL: 'https://api.example.com',
          BRICKS_PLUGIN_ID: 'plugin-id',
          BRICKS_PLATFORM_TOKEN: 'jwt-token',
        },
      },
    };

    expect(bricksChannelPlugin.config.listAccountIds(cfg)).toEqual([DEFAULT_ACCOUNT_ID]);
    expect(bricksChannelPlugin.config.resolveAccount(cfg).configured).toBe(true);
    expect(await bricksChannelPlugin.setupWizard.status.resolveConfigured({ cfg })).toBe(true);
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
