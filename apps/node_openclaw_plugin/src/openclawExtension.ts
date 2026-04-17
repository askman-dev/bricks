const CHANNEL_ID = 'dev-askman-bricks';

interface PromptApi {
  input(options: { message: string; default?: string }): Promise<string>;
}

interface OnboardingContext {
  configured: boolean;
  label?: string;
  config?: Record<string, unknown>;
  prompter?: PromptApi;
}

interface OnboardingResult {
  cfg: Record<string, string>;
  accountId?: string;
}

function readExistingConfigValue(config: OnboardingContext['config'], key: string): string | undefined {
  const value = config?.[key];
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

async function promptRequired(
  ctx: OnboardingContext,
  key: 'BRICKS_BASE_URL' | 'BRICKS_PLUGIN_ID' | 'BRICKS_PLATFORM_TOKEN',
  promptMessage: string,
  fallback?: string,
): Promise<string> {
  if (!ctx.prompter?.input) {
    throw new Error(`Missing onboarding prompter; please set channels.${CHANNEL_ID}.${key} manually.`);
  }

  const existing = readExistingConfigValue(ctx.config, key) ?? fallback;
  const entered = (await ctx.prompter.input({
    message: promptMessage,
    default: existing,
  }))?.trim();

  if (!entered) {
    throw new Error(`${key} is required.`);
  }

  return entered;
}

const plugin = {
  id: CHANNEL_ID,
  name: 'Bricks OpenClaw Plugin',
  configSchema: {
    type: 'object',
    additionalProperties: false,
    properties: {},
  },
  onboarding: {
    async configureInteractive(ctx: OnboardingContext): Promise<OnboardingResult> {
      const label = ctx.label ?? 'Bricks';

      const baseUrl = await promptRequired(ctx, 'BRICKS_BASE_URL', `Enter ${label} BRICKS_BASE_URL`);
      const pluginId = await promptRequired(ctx, 'BRICKS_PLUGIN_ID', `Enter ${label} BRICKS_PLUGIN_ID`, CHANNEL_ID);
      const token = await promptRequired(ctx, 'BRICKS_PLATFORM_TOKEN', `Enter ${label} BRICKS_PLATFORM_TOKEN (JWT)`);

      return {
        cfg: {
          BRICKS_BASE_URL: baseUrl,
          BRICKS_PLUGIN_ID: pluginId,
          BRICKS_PLATFORM_TOKEN: token,
        },
        accountId: pluginId,
      };
    },
  },
  register() {
    // Runtime behavior is implemented in src/index.ts for standalone pull-only runner.
    // This extension focuses on OpenClaw discovery + onboarding config wiring.
  },
};

export default plugin;
