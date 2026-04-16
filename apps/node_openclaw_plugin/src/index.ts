import { homedir } from 'node:os';
import { join } from 'node:path';
import { parseAndValidatePlatformTokenClaims } from './jwtClaims.js';
import { NodeOpenClawPluginRunner } from './pluginRunner.js';
import type { PluginRuntimeConfig } from './types.js';

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env: ${name}`);
  }
  return value;
}

function loadConfig(): PluginRuntimeConfig {
  const pollIntervalMs = Number(process.env.OPENCLAW_PLUGIN_POLL_INTERVAL_MS ?? '2000');
  if (!Number.isFinite(pollIntervalMs) || pollIntervalMs <= 0) {
    throw new Error('OPENCLAW_PLUGIN_POLL_INTERVAL_MS must be a positive number');
  }

  const token = requiredEnv('BRICKS_PLATFORM_TOKEN');
  const pluginId = requiredEnv('BRICKS_PLUGIN_ID');
  const tokenClaims = parseAndValidatePlatformTokenClaims(token, pluginId);

  return {
    baseUrl: requiredEnv('BRICKS_BASE_URL'),
    token,
    pluginId,
    tokenUserId: tokenClaims.userId,
    pollIntervalMs,
    defaultCursor: process.env.OPENCLAW_PLUGIN_DEFAULT_CURSOR?.trim() || 'cur_0',
    stateFilePath:
      process.env.OPENCLAW_PLUGIN_STATE_FILE?.trim() ||
      join(homedir(), '.bricks', 'node_openclaw_plugin_state.json'),
    assistantName: process.env.OPENCLAW_PLUGIN_ASSISTANT_NAME?.trim() || 'Node OpenClaw Plugin',
  };
}

async function main(): Promise<void> {
  const config = loadConfig();
  const runner = new NodeOpenClawPluginRunner(config);
  await runner.runForever();
}

main().catch((error) => {
  console.error('Failed to start node_openclaw_plugin:', error);
  process.exitCode = 1;
});
