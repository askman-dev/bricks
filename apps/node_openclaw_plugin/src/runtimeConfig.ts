import { homedir } from 'node:os';
import { join } from 'node:path';
import { parseAndValidatePlatformTokenClaims } from './jwtClaims.js';
import type { PluginRuntimeConfig } from './types.js';

const DEFAULT_CURSOR = 'cur_0';
const DEFAULT_POLL_INTERVAL_MS = 2000;
const DEFAULT_ASSISTANT_NAME = 'Node OpenClaw Plugin';

interface BuildPluginRuntimeConfigInput {
  baseUrl: string;
  token: string;
  pluginId: string;
  pollIntervalMs?: string | number;
  defaultCursor?: string;
  stateFilePath?: string;
  assistantName?: string;
}

function requiredValue(name: string, value: string | undefined): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    throw new Error(`Missing required value: ${name}`);
  }
  return trimmed;
}

function parsePollInterval(value: string | number | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(value ?? DEFAULT_POLL_INTERVAL_MS);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error('OPENCLAW_PLUGIN_POLL_INTERVAL_MS must be a positive number');
  }
  return parsed;
}

export function defaultStateFilePath(): string {
  return join(homedir(), '.bricks', 'node_openclaw_plugin_state.json');
}

export function buildPluginRuntimeConfig(
  input: BuildPluginRuntimeConfigInput,
): PluginRuntimeConfig {
  const baseUrl = requiredValue('BRICKS_BASE_URL', input.baseUrl);
  const token = requiredValue('BRICKS_PLATFORM_TOKEN', input.token);
  const pluginId = requiredValue('BRICKS_PLUGIN_ID', input.pluginId);
  const tokenClaims = parseAndValidatePlatformTokenClaims(token, pluginId);

  return {
    baseUrl,
    token,
    pluginId,
    tokenUserId: tokenClaims.userId,
    pollIntervalMs: parsePollInterval(input.pollIntervalMs),
    defaultCursor: input.defaultCursor?.trim() || DEFAULT_CURSOR,
    stateFilePath: input.stateFilePath?.trim() || defaultStateFilePath(),
    assistantName: input.assistantName?.trim() || DEFAULT_ASSISTANT_NAME,
  };
}

export function loadPluginRuntimeConfigFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): PluginRuntimeConfig {
  return buildPluginRuntimeConfig({
    baseUrl: requiredValue('BRICKS_BASE_URL', env.BRICKS_BASE_URL),
    token: requiredValue('BRICKS_PLATFORM_TOKEN', env.BRICKS_PLATFORM_TOKEN),
    pluginId: requiredValue('BRICKS_PLUGIN_ID', env.BRICKS_PLUGIN_ID),
    pollIntervalMs: env.OPENCLAW_PLUGIN_POLL_INTERVAL_MS,
    defaultCursor: env.OPENCLAW_PLUGIN_DEFAULT_CURSOR,
    stateFilePath: env.OPENCLAW_PLUGIN_STATE_FILE,
    assistantName: env.OPENCLAW_PLUGIN_ASSISTANT_NAME,
  });
}
