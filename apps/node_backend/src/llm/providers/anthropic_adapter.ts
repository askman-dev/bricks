import { createAnthropic } from '@ai-sdk/anthropic';
import type { LanguageModel } from 'ai';
import { LlmProviderAdapter, LlmRuntimeConfig } from '../types.js';

export class AnthropicAdapter implements LlmProviderAdapter {
  readonly provider = 'anthropic' as const;

  createModel(modelId: string, config: LlmRuntimeConfig): LanguageModel {
    const anthropic = createAnthropic({
      baseURL: `${stripTrailingSlash(config.baseUrl)}/v1`,
      apiKey: config.apiKey,
    });
    return anthropic(modelId);
  }
}

function stripTrailingSlash(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}
