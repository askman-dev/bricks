import { generateText, streamText } from 'ai';
import type { LanguageModel } from 'ai';
import { getApiConfigs } from '../services/configService.js';
import { AnthropicAdapter } from './providers/anthropic_adapter.js';
import { GoogleAiStudioAdapter } from './providers/google_ai_studio_adapter.js';
import { LlmProvider, LlmProviderAdapter, LlmRuntimeConfig, UnifiedChatRequest, UnifiedChatResponse } from './types.js';

const adapters: Record<LlmProvider, LlmProviderAdapter> = {
  anthropic: new AnthropicAdapter(),
  google_ai_studio: new GoogleAiStudioAdapter(),
};

const ALLOWED_ENDPOINT_HOSTS = new Set([
  'api.anthropic.com',
  'generativelanguage.googleapis.com',
]);

function validateEndpointUrl(endpoint: string): void {
  let parsed: URL;
  try {
    parsed = new URL(endpoint);
  } catch {
    throw new Error('Invalid endpoint URL');
  }
  if (parsed.protocol !== 'https:') {
    throw new Error('Endpoint must use HTTPS');
  }
  if (!ALLOWED_ENDPOINT_HOSTS.has(parsed.hostname)) {
    throw new Error(`Endpoint host '${parsed.hostname}' is not allowed`);
  }
}

interface StoredLlmConfig {
  id: string;
  provider: string;
  is_default: boolean;
  config: {
    endpoint?: unknown;
    api_key?: unknown;
    model_preferences?: {
      default_model?: unknown;
    };
  };
}

function resolveModel(
  request: UnifiedChatRequest,
  runtimeConfig: LlmRuntimeConfig
): { model: LanguageModel; modelId: string } {
  const modelId = request.model || runtimeConfig.defaultModel;
  const adapter = adapters[runtimeConfig.provider];
  return { model: adapter.createModel(modelId, runtimeConfig), modelId };
}

export async function generateWithUserConfig(
  userId: string,
  request: UnifiedChatRequest,
  preferredProvider?: LlmProvider
): Promise<UnifiedChatResponse> {
  const runtimeConfig = await resolveRuntimeConfig(userId, preferredProvider);
  const { model, modelId } = resolveModel(request, runtimeConfig);

  const result = await generateText({
    model,
    messages: request.messages.map((m) => ({
      role: m.role,
      content: m.content,
    })),
    temperature: request.temperature,
    maxOutputTokens: request.maxTokens ?? 1024,
  });

  return {
    provider: runtimeConfig.provider,
    model: modelId,
    text: result.text,
  };
}

export async function streamWithUserConfig(
  userId: string,
  request: UnifiedChatRequest,
  preferredProvider?: LlmProvider
): Promise<{ textStream: AsyncIterable<string>; provider: LlmProvider; modelId: string }> {
  const runtimeConfig = await resolveRuntimeConfig(userId, preferredProvider);
  const { model, modelId } = resolveModel(request, runtimeConfig);

  const result = streamText({
    model,
    messages: request.messages.map((m) => ({
      role: m.role,
      content: m.content,
    })),
    temperature: request.temperature,
    maxOutputTokens: request.maxTokens ?? 1024,
  });

  return { textStream: result.textStream, provider: runtimeConfig.provider, modelId };
}

async function resolveRuntimeConfig(
  userId: string,
  preferredProvider?: LlmProvider
): Promise<LlmRuntimeConfig> {
  const allConfigs = (await getApiConfigs(userId, 'llm')) as StoredLlmConfig[];
  if (allConfigs.length === 0) {
    throw new Error('No LLM configuration found for user');
  }

  const selected =
    (preferredProvider
      ? allConfigs.find((cfg) => cfg.provider === preferredProvider)
      : undefined) ??
    allConfigs.find((cfg) => cfg.is_default) ??
    allConfigs[0];

  const provider = parseProvider(selected.provider);
  if (!provider) {
    throw new Error(`Unsupported provider: ${selected.provider}`);
  }

  const endpoint = selected.config?.endpoint;
  const apiKey = selected.config?.api_key;
  const defaultModel = selected.config?.model_preferences?.default_model;

  if (typeof endpoint !== 'string' || !endpoint.trim()) {
    throw new Error('Invalid provider endpoint');
  }
  validateEndpointUrl(endpoint);
  if (typeof apiKey !== 'string' || !apiKey.trim()) {
    throw new Error('Invalid provider api_key');
  }

  return {
    provider,
    baseUrl: endpoint,
    apiKey,
    defaultModel:
      typeof defaultModel === 'string' && defaultModel.trim()
        ? defaultModel
        : fallbackModel(provider),
  };
}

function fallbackModel(provider: LlmProvider): string {
  switch (provider) {
    case 'google_ai_studio':
      return 'gemini-flash-latest';
    case 'anthropic':
      return 'claude-sonnet-4-5';
  }
}

function parseProvider(provider: string): LlmProvider | null {
  if (provider === 'anthropic' || provider === 'google_ai_studio') {
    return provider;
  }
  return null;
}
