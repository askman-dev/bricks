export const CHANNEL_ID = 'dev-askman-bricks';
export const CHANNEL_NAME = 'Bricks OpenClaw Plugin';
export const CHANNEL_DESCRIPTION = 'Bricks pull-only OpenClaw channel plugin with interactive onboarding.';
export const DEFAULT_ACCOUNT_ID = 'default';

type BricksConfigKey = 'BRICKS_BASE_URL' | 'BRICKS_PLUGIN_ID' | 'BRICKS_PLATFORM_TOKEN';
type JsonObject = Record<string, unknown>;
type WizardCredentialValues = Partial<Record<string, string>>;

export interface OpenClawConfig extends JsonObject {
  channels?: Record<string, unknown>;
}

interface ChannelSetupInput extends JsonObject {
  BRICKS_BASE_URL?: unknown;
  BRICKS_PLUGIN_ID?: unknown;
  BRICKS_PLATFORM_TOKEN?: unknown;
}

interface BricksStoredConfig {
  BRICKS_BASE_URL?: string;
  BRICKS_PLUGIN_ID?: string;
  BRICKS_PLATFORM_TOKEN?: string;
}

interface BricksResolvedAccount {
  accountId: string;
  enabled: boolean;
  configured: boolean;
  config: BricksStoredConfig;
}

interface ChannelConfigSchema {
  schema: JsonObject;
  uiHints?: Record<string, JsonObject>;
}

interface ChannelMeta {
  id: string;
  label: string;
  selectionLabel?: string;
  docsPath?: string;
  docsLabel?: string;
  blurb?: string;
  order?: number;
  aliases?: string[];
}

interface ChannelCapabilities {
  chatTypes?: string[];
  media?: boolean;
}

interface ChannelSetupAdapter {
  resolveAccountId?: (params: { cfg: OpenClawConfig; accountId?: string; input?: ChannelSetupInput }) => string;
  applyAccountConfig: (params: { cfg: OpenClawConfig; accountId: string; input: ChannelSetupInput }) => OpenClawConfig;
  validateInput?: (params: { cfg: OpenClawConfig; accountId: string; input: ChannelSetupInput }) => string | null;
}

interface ChannelConfigAdapter {
  listAccountIds: (cfg: OpenClawConfig) => string[];
  resolveAccount: (cfg: OpenClawConfig, accountId?: string | null) => BricksResolvedAccount;
  defaultAccountId?: (cfg: OpenClawConfig) => string;
  inspectAccount?: (cfg: OpenClawConfig, accountId?: string | null) => JsonObject;
  isConfigured?: (account: BricksResolvedAccount, cfg: OpenClawConfig) => boolean;
  describeAccount?: (account: BricksResolvedAccount, cfg: OpenClawConfig) => JsonObject;
}

interface ChannelSetupWizardStatus {
  configuredLabel: string;
  unconfiguredLabel: string;
  configuredHint?: string;
  unconfiguredHint?: string;
  configuredScore?: number;
  unconfiguredScore?: number;
  resolveConfigured: (params: { cfg: OpenClawConfig; accountId?: string }) => boolean | Promise<boolean>;
  resolveSelectionHint?: (params: {
    cfg: OpenClawConfig;
    accountId?: string;
    configured: boolean;
  }) => string | undefined | Promise<string | undefined>;
}

interface ChannelSetupWizardCredentialState {
  accountConfigured: boolean;
  hasConfiguredValue: boolean;
  resolvedValue?: string;
}

interface ChannelSetupWizardCredential {
  inputKey: keyof ChannelSetupInput;
  providerHint: string;
  credentialLabel: string;
  envPrompt: string;
  keepPrompt: string;
  inputPrompt: string;
  inspect: (params: { cfg: OpenClawConfig; accountId: string }) => ChannelSetupWizardCredentialState;
  applySet?: (params: {
    cfg: OpenClawConfig;
    accountId: string;
    credentialValues: WizardCredentialValues;
    value: unknown;
    resolvedValue: string;
  }) => OpenClawConfig | Promise<OpenClawConfig>;
}

interface ChannelSetupWizardTextInput {
  inputKey: keyof ChannelSetupInput;
  message: string;
  placeholder?: string;
  required?: boolean;
  currentValue?: (params: {
    cfg: OpenClawConfig;
    accountId: string;
    credentialValues: WizardCredentialValues;
  }) => string | undefined | Promise<string | undefined>;
  validate?: (params: {
    value: string;
    cfg: OpenClawConfig;
    accountId: string;
    credentialValues: WizardCredentialValues;
  }) => string | undefined;
  normalizeValue?: (params: {
    value: string;
    cfg: OpenClawConfig;
    accountId: string;
    credentialValues: WizardCredentialValues;
  }) => string | Promise<string>;
  applySet?: (params: {
    cfg: OpenClawConfig;
    accountId: string;
    credentialValues: WizardCredentialValues;
    value: string;
  }) => OpenClawConfig | Promise<OpenClawConfig>;
}

interface ChannelSetupWizard {
  channel: string;
  status: ChannelSetupWizardStatus;
  stepOrder?: 'credentials-first' | 'text-first';
  credentials: ChannelSetupWizardCredential[];
  textInputs?: ChannelSetupWizardTextInput[];
}

export interface BricksChannelPlugin {
  id: string;
  meta: ChannelMeta;
  capabilities: ChannelCapabilities;
  reload: { configPrefixes: string[] };
  configSchema: ChannelConfigSchema;
  config: ChannelConfigAdapter;
  setup: ChannelSetupAdapter;
  setupWizard: ChannelSetupWizard;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function readOptionalString(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function readStoredChannelConfig(cfg: OpenClawConfig): BricksStoredConfig {
  const channels = isRecord(cfg.channels) ? cfg.channels : {};
  const rawChannelConfig = channels[CHANNEL_ID];
  const channelConfig = isRecord(rawChannelConfig) ? rawChannelConfig : {};

  return {
    BRICKS_BASE_URL: readOptionalString(channelConfig.BRICKS_BASE_URL),
    BRICKS_PLUGIN_ID: readOptionalString(channelConfig.BRICKS_PLUGIN_ID),
    BRICKS_PLATFORM_TOKEN: readOptionalString(channelConfig.BRICKS_PLATFORM_TOKEN),
  };
}

function hasStoredChannelSection(cfg: OpenClawConfig): boolean {
  const channels = isRecord(cfg.channels) ? cfg.channels : {};
  return isRecord(channels[CHANNEL_ID]);
}

function isBricksChannelConfigured(config: BricksStoredConfig): boolean {
  return Boolean(config.BRICKS_BASE_URL && config.BRICKS_PLUGIN_ID && config.BRICKS_PLATFORM_TOKEN);
}

function readInputValue(input: ChannelSetupInput, key: BricksConfigKey): string | undefined {
  return readOptionalString(input[key]);
}

function validateRequiredValue(key: BricksConfigKey, value: string | undefined): string | null {
  return value ? null : `${key} is required`;
}

function mergeChannelConfig(cfg: OpenClawConfig, patch: Partial<Record<BricksConfigKey, string>>): OpenClawConfig {
  const channels = isRecord(cfg.channels) ? cfg.channels : {};
  const existingChannelConfig = isRecord(channels[CHANNEL_ID]) ? channels[CHANNEL_ID] : {};
  const nextChannelConfig: Record<string, unknown> = { ...existingChannelConfig };

  for (const [key, value] of Object.entries(patch)) {
    if (value !== undefined) {
      nextChannelConfig[key] = value;
    }
  }

  return {
    ...cfg,
    channels: {
      ...channels,
      [CHANNEL_ID]: nextChannelConfig,
    },
  };
}

function resolveConfiguredValue(
  input: ChannelSetupInput,
  existingConfig: BricksStoredConfig,
  key: BricksConfigKey,
): string {
  const value = readInputValue(input, key) ?? existingConfig[key];
  if (!value) {
    throw new Error(`${key} is required`);
  }

  return value;
}

function applySingleField(
  cfg: OpenClawConfig,
  key: BricksConfigKey,
  value: unknown,
): OpenClawConfig {
  const resolvedValue = readOptionalString(value);
  if (!resolvedValue) {
    throw new Error(`${key} is required`);
  }

  return mergeChannelConfig(cfg, { [key]: resolvedValue });
}

export const BRICKS_CHANNEL_CONFIG_SCHEMA: ChannelConfigSchema = {
  schema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      BRICKS_BASE_URL: {
        type: 'string',
        minLength: 1,
      },
      BRICKS_PLUGIN_ID: {
        type: 'string',
        minLength: 1,
      },
      BRICKS_PLATFORM_TOKEN: {
        type: 'string',
        minLength: 1,
      },
    },
  },
  uiHints: {
    BRICKS_BASE_URL: {
      label: 'Bricks Base URL',
      placeholder: 'https://api.example.com',
    },
    BRICKS_PLUGIN_ID: {
      label: 'Bricks Plugin ID',
      placeholder: CHANNEL_ID,
    },
    BRICKS_PLATFORM_TOKEN: {
      label: 'Bricks Platform Token',
      sensitive: true,
      placeholder: 'paste your JWT platform token',
    },
  },
};

const bricksConfigAdapter: ChannelConfigAdapter = {
  listAccountIds(cfg) {
    return hasStoredChannelSection(cfg) ? [DEFAULT_ACCOUNT_ID] : [];
  },
  resolveAccount(cfg, accountId) {
    const resolvedAccountId = readOptionalString(accountId) ?? DEFAULT_ACCOUNT_ID;
    const config = readStoredChannelConfig(cfg);

    return {
      accountId: resolvedAccountId,
      enabled: true,
      configured: isBricksChannelConfigured(config),
      config,
    };
  },
  defaultAccountId() {
    return DEFAULT_ACCOUNT_ID;
  },
  inspectAccount(cfg, accountId) {
    const account = this.resolveAccount(cfg, accountId);
    return {
      enabled: account.enabled,
      configured: account.configured,
      tokenStatus: account.config.BRICKS_PLATFORM_TOKEN ? 'available' : 'missing',
      pluginId: account.config.BRICKS_PLUGIN_ID ?? null,
      baseUrl: account.config.BRICKS_BASE_URL ?? null,
    };
  },
  isConfigured(account) {
    return account.configured;
  },
  describeAccount(account) {
    return {
      accountId: account.accountId,
      enabled: account.enabled,
      configured: account.configured,
      extra: {
        baseUrl: account.config.BRICKS_BASE_URL ?? null,
        pluginId: account.config.BRICKS_PLUGIN_ID ?? null,
      },
    };
  },
};

const bricksSetupAdapter: ChannelSetupAdapter = {
  resolveAccountId() {
    return DEFAULT_ACCOUNT_ID;
  },
  validateInput({ cfg, input }) {
    const existingConfig = readStoredChannelConfig(cfg);
    const baseUrlError = validateRequiredValue(
      'BRICKS_BASE_URL',
      readInputValue(input, 'BRICKS_BASE_URL') ?? existingConfig.BRICKS_BASE_URL,
    );
    if (baseUrlError) {
      return baseUrlError;
    }

    const pluginIdError = validateRequiredValue(
      'BRICKS_PLUGIN_ID',
      readInputValue(input, 'BRICKS_PLUGIN_ID') ?? existingConfig.BRICKS_PLUGIN_ID,
    );
    if (pluginIdError) {
      return pluginIdError;
    }

    return validateRequiredValue(
      'BRICKS_PLATFORM_TOKEN',
      readInputValue(input, 'BRICKS_PLATFORM_TOKEN') ?? existingConfig.BRICKS_PLATFORM_TOKEN,
    );
  },
  applyAccountConfig({ cfg, input }) {
    const existingConfig = readStoredChannelConfig(cfg);
    return mergeChannelConfig(cfg, {
      BRICKS_BASE_URL: resolveConfiguredValue(input, existingConfig, 'BRICKS_BASE_URL'),
      BRICKS_PLUGIN_ID: resolveConfiguredValue(input, existingConfig, 'BRICKS_PLUGIN_ID'),
      BRICKS_PLATFORM_TOKEN: resolveConfiguredValue(input, existingConfig, 'BRICKS_PLATFORM_TOKEN'),
    });
  },
};

const bricksSetupWizard: ChannelSetupWizard = {
  channel: CHANNEL_ID,
  stepOrder: 'text-first',
  status: {
    configuredLabel: 'configured',
    unconfiguredLabel: 'needs BRICKS_* config',
    configuredHint: 'configured',
    unconfiguredHint: 'requires Bricks base URL, plugin id, and platform token',
    configuredScore: 1,
    unconfiguredScore: 0,
    resolveConfigured: ({ cfg }) => isBricksChannelConfigured(readStoredChannelConfig(cfg)),
    resolveSelectionHint: ({ configured }) =>
      configured ? 'configured' : 'Bricks pull-only platform channel',
  },
  credentials: [
    {
      inputKey: 'BRICKS_PLATFORM_TOKEN',
      providerHint: CHANNEL_ID,
      credentialLabel: 'Bricks Platform Token',
      envPrompt: '',
      keepPrompt: 'Bricks Platform Token already configured. Keep it?',
      inputPrompt: 'Enter Bricks BRICKS_PLATFORM_TOKEN (JWT)',
      inspect: ({ cfg }) => {
        const config = readStoredChannelConfig(cfg);
        return {
          accountConfigured: isBricksChannelConfigured(config),
          hasConfiguredValue: Boolean(config.BRICKS_PLATFORM_TOKEN),
        };
      },
      applySet: ({ cfg, resolvedValue }) =>
        applySingleField(cfg, 'BRICKS_PLATFORM_TOKEN', resolvedValue),
    },
  ],
  textInputs: [
    {
      inputKey: 'BRICKS_BASE_URL',
      message: 'Bricks Base URL',
      placeholder: 'https://api.example.com',
      required: true,
      currentValue: ({ cfg }) => readStoredChannelConfig(cfg).BRICKS_BASE_URL,
      validate: ({ value }) => validateRequiredValue('BRICKS_BASE_URL', readOptionalString(value)) ?? undefined,
      normalizeValue: ({ value }) => value.trim(),
      applySet: ({ cfg, value }) => applySingleField(cfg, 'BRICKS_BASE_URL', value),
    },
    {
      inputKey: 'BRICKS_PLUGIN_ID',
      message: 'Bricks Plugin ID',
      placeholder: CHANNEL_ID,
      required: true,
      currentValue: ({ cfg }) => readStoredChannelConfig(cfg).BRICKS_PLUGIN_ID,
      validate: ({ value }) => validateRequiredValue('BRICKS_PLUGIN_ID', readOptionalString(value)) ?? undefined,
      normalizeValue: ({ value }) => value.trim(),
      applySet: ({ cfg, value }) => applySingleField(cfg, 'BRICKS_PLUGIN_ID', value),
    },
  ],
};

export const bricksChannelPlugin: BricksChannelPlugin = {
  id: CHANNEL_ID,
  meta: {
    id: CHANNEL_ID,
    label: 'Bricks',
    selectionLabel: 'Bricks Platform',
    docsPath: '/channels/dev-askman-bricks',
    docsLabel: CHANNEL_ID,
    blurb: 'Bricks platform pull-only channel with onboarding wizard.',
    order: 70,
    aliases: ['bricks'],
  },
  capabilities: {
    chatTypes: ['direct'],
    media: false,
  },
  reload: {
    configPrefixes: [`channels.${CHANNEL_ID}`],
  },
  configSchema: BRICKS_CHANNEL_CONFIG_SCHEMA,
  config: bricksConfigAdapter,
  setup: bricksSetupAdapter,
  setupWizard: bricksSetupWizard,
};
