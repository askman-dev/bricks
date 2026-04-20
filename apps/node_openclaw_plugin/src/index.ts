import { NodeOpenClawPluginRunner } from './pluginRunner.js';
import { loadPluginRuntimeConfigFromEnv } from './runtimeConfig.js';

async function main(): Promise<void> {
  const config = loadPluginRuntimeConfigFromEnv();
  const runner = new NodeOpenClawPluginRunner(config);
  await runner.runForever();
}

main().catch((error) => {
  console.error('Failed to start node_openclaw_plugin:', error);
  process.exitCode = 1;
});
