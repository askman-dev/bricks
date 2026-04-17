import { describe, expect, it, vi } from 'vitest';
import plugin from '../src/openclawExtension.js';

function makePrompter(responses: string[]) {
  let call = 0;
  return {
    input: vi.fn(async (_opts: { message: string; default?: string }) => responses[call++] ?? ''),
  };
}

describe('openclawExtension plugin', () => {
  describe('configSchema', () => {
    it('declares all required BRICKS_* keys', () => {
      const { configSchema } = plugin;
      expect(configSchema.required).toEqual(
        expect.arrayContaining(['BRICKS_BASE_URL', 'BRICKS_PLUGIN_ID', 'BRICKS_PLATFORM_TOKEN']),
      );
      expect(configSchema.properties).toHaveProperty('BRICKS_BASE_URL');
      expect(configSchema.properties).toHaveProperty('BRICKS_PLUGIN_ID');
      expect(configSchema.properties).toHaveProperty('BRICKS_PLATFORM_TOKEN');
    });

    it('has additionalProperties set to false', () => {
      expect(plugin.configSchema.additionalProperties).toBe(false);
    });
  });

  describe('configureInteractive', () => {
    it('collects BRICKS_* values from prompter and returns cfg + accountId', async () => {
      const prompter = makePrompter(['https://api.example.com', 'my-plugin-id', 'jwt-token']);
      const result = await plugin.onboarding.configureInteractive({ configured: false, prompter });

      expect(result.cfg).toEqual({
        BRICKS_BASE_URL: 'https://api.example.com',
        BRICKS_PLUGIN_ID: 'my-plugin-id',
        BRICKS_PLATFORM_TOKEN: 'jwt-token',
      });
      expect(result.accountId).toBe('my-plugin-id');
    });

    it('uses existing config values as defaults', async () => {
      const prompter = makePrompter(['', '', '']);
      prompter.input = vi.fn(async (opts: { message: string; default?: string }) => opts.default ?? '');

      const result = await plugin.onboarding.configureInteractive({
        configured: true,
        prompter,
        config: {
          BRICKS_BASE_URL: 'https://stored.example.com',
          BRICKS_PLUGIN_ID: 'stored-plugin',
          BRICKS_PLATFORM_TOKEN: 'stored-token',
        },
      });

      expect(result.cfg.BRICKS_BASE_URL).toBe('https://stored.example.com');
      expect(result.cfg.BRICKS_PLUGIN_ID).toBe('stored-plugin');
      expect(result.cfg.BRICKS_PLATFORM_TOKEN).toBe('stored-token');
    });

    it('trims whitespace from entered values', async () => {
      const prompter = makePrompter(['  https://api.example.com  ', '  plugin-id  ', '  token  ']);
      const result = await plugin.onboarding.configureInteractive({ configured: false, prompter });

      expect(result.cfg.BRICKS_BASE_URL).toBe('https://api.example.com');
      expect(result.cfg.BRICKS_PLUGIN_ID).toBe('plugin-id');
      expect(result.cfg.BRICKS_PLATFORM_TOKEN).toBe('token');
    });

    it('throws when prompter is missing', async () => {
      await expect(plugin.onboarding.configureInteractive({ configured: false })).rejects.toThrow(
        'Missing onboarding prompter',
      );
    });

    it('throws when a required value is empty after trim', async () => {
      const prompter = makePrompter(['', '', '']);
      await expect(plugin.onboarding.configureInteractive({ configured: false, prompter })).rejects.toThrow(
        'BRICKS_BASE_URL is required',
      );
    });
  });
});
