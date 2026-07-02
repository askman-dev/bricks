import path from 'path';

export interface RunnerConfig {
  host: string;
  port: number;
  token: string | null;
  sandboxRoot: string;
  dockerBin: string;
  runtime: string;
  image: string;
  network: string;
  containerPrefix: string;
  maxOutputBytes: number;
  defaultTimeoutMs: number;
}

function readInt(name: string, fallback: number): number {
  const value = process.env[name]?.trim();
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function loadConfig(): RunnerConfig {
  return {
    host: process.env.SANDBOX_RUNNER_HOST?.trim() || '127.0.0.1',
    port: readInt('SANDBOX_RUNNER_PORT', 8787),
    token: process.env.SANDBOX_RUNNER_TOKEN?.trim() || null,
    sandboxRoot: path.resolve(process.env.SANDBOX_ROOT || '/srv/bricks/sandboxes'),
    dockerBin: process.env.SANDBOX_DOCKER_BIN?.trim() || 'docker',
    runtime: process.env.SANDBOX_DOCKER_RUNTIME?.trim() || 'runsc',
    image: process.env.SANDBOX_IMAGE?.trim() || 'node:22-bookworm',
    network: process.env.SANDBOX_NETWORK?.trim() || 'bridge',
    containerPrefix: process.env.SANDBOX_CONTAINER_PREFIX?.trim() || 'bricks-sandbox',
    maxOutputBytes: readInt('SANDBOX_MAX_OUTPUT_BYTES', 256 * 1024),
    defaultTimeoutMs: readInt('SANDBOX_DEFAULT_TIMEOUT_MS', 120_000),
  };
}
