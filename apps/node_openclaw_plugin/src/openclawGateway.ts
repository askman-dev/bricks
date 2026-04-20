import { NodeOpenClawPluginRunner } from './pluginRunner.js';
import { buildPluginRuntimeConfig } from './runtimeConfig.js';
import type { PluginRuntimeConfig, RunnerLogSink } from './types.js';

interface BricksGatewayAccountConfig {
  BRICKS_BASE_URL?: string;
  BRICKS_PLUGIN_ID?: string;
  BRICKS_PLATFORM_TOKEN?: string;
}

interface BricksGatewayAccount {
  accountId: string;
  config: BricksGatewayAccountConfig;
}

interface ChannelAccountSnapshot {
  accountId: string;
  baseUrl?: string | null;
  tokenStatus?: string;
  mode?: string;
  lastError?: string | null;
  lastStopAt?: number | null;
  [key: string]: unknown;
}

interface ChannelLogSink {
  info?: (message: string) => void;
  warn?: (message: string) => void;
  error?: (message: string) => void;
}

interface BricksGatewayContext {
  accountId: string;
  account: BricksGatewayAccount;
  abortSignal: AbortSignal;
  log?: ChannelLogSink;
  getStatus: () => ChannelAccountSnapshot;
  setStatus: (next: ChannelAccountSnapshot) => void;
}

interface GatewayRunnerLike {
  runUntilAbort(abortSignal: AbortSignal): Promise<void>;
}

interface BricksGatewayDeps {
  env: NodeJS.ProcessEnv;
  now: () => number;
  createRunner: (config: PluginRuntimeConfig, log?: RunnerLogSink) => GatewayRunnerLike;
}

export interface ChannelGatewayAdapter {
  startAccount: (ctx: BricksGatewayContext) => Promise<unknown>;
  stopAccount: (ctx: BricksGatewayContext) => Promise<void>;
}

const defaultDeps: BricksGatewayDeps = {
  env: process.env,
  now: () => Date.now(),
  createRunner: (config, log) => new NodeOpenClawPluginRunner(config, { log }),
};

function toRunnerLog(log?: ChannelLogSink): RunnerLogSink | undefined {
  if (!log) {
    return undefined;
  }

  return {
    info: (message) => log.info?.(message),
    warn: (message) => log.warn?.(message),
    error: (message) => log.error?.(message),
  };
}

function formatGatewayError(error: unknown): string {
  if (error instanceof Error) {
    return error.stack ?? `${error.name}: ${error.message}`;
  }
  return String(error);
}

export function buildGatewayRunnerConfig(
  account: BricksGatewayAccount,
  env: NodeJS.ProcessEnv = process.env,
): PluginRuntimeConfig {
  return buildPluginRuntimeConfig({
    baseUrl: account.config.BRICKS_BASE_URL ?? '',
    token: account.config.BRICKS_PLATFORM_TOKEN ?? '',
    pluginId: account.config.BRICKS_PLUGIN_ID ?? '',
    pollIntervalMs: env.OPENCLAW_PLUGIN_POLL_INTERVAL_MS,
    defaultCursor: env.OPENCLAW_PLUGIN_DEFAULT_CURSOR,
    stateFilePath: env.OPENCLAW_PLUGIN_STATE_FILE,
    assistantName: env.OPENCLAW_PLUGIN_ASSISTANT_NAME,
  });
}

export function createBricksGatewayAdapter(
  deps: Partial<BricksGatewayDeps> = {},
): ChannelGatewayAdapter {
  const resolvedDeps: BricksGatewayDeps = {
    ...defaultDeps,
    ...deps,
  };

  return {
    async startAccount(ctx) {
      try {
        const runnerConfig = buildGatewayRunnerConfig(ctx.account, resolvedDeps.env);
        ctx.log?.info?.(`[${ctx.accountId}] starting Bricks pull runner`);
        ctx.setStatus({
          ...ctx.getStatus(),
          accountId: ctx.accountId,
          baseUrl: runnerConfig.baseUrl,
          tokenStatus: 'available',
          mode: 'pull',
          lastError: null,
        });

        const runner = resolvedDeps.createRunner(runnerConfig, toRunnerLog(ctx.log));
        await runner.runUntilAbort(ctx.abortSignal);
      } catch (error) {
        ctx.setStatus({
          ...ctx.getStatus(),
          accountId: ctx.accountId,
          lastError: formatGatewayError(error),
        });
        throw error;
      }
    },
    async stopAccount(ctx) {
      ctx.log?.info?.(`[${ctx.accountId}] stopping Bricks pull runner`);
      ctx.setStatus({
        ...ctx.getStatus(),
        accountId: ctx.accountId,
        lastStopAt: resolvedDeps.now(),
      });
    },
  };
}
