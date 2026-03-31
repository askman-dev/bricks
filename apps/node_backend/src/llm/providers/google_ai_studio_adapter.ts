import { createGoogleGenerativeAI } from '@ai-sdk/google';
import type { LanguageModel } from 'ai';
import { LlmProviderAdapter, LlmRuntimeConfig } from '../types.js';

export class GoogleAiStudioAdapter implements LlmProviderAdapter {
  readonly provider = 'google_ai_studio' as const;

  createModel(modelId: string, config: LlmRuntimeConfig): LanguageModel {
    const google = createGoogleGenerativeAI({
      baseURL: `${stripTrailingSlash(config.baseUrl)}/v1beta`,
      apiKey: config.apiKey,
    });
    return google(modelId);
  }
}

function stripTrailingSlash(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}
