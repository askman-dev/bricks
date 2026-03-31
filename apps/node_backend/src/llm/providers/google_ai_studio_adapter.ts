import axios from 'axios';
import { LlmProviderAdapter, LlmRuntimeConfig, UnifiedChatRequest, UnifiedChatResponse } from '../types.js';

export class GoogleAiStudioAdapter implements LlmProviderAdapter {
  readonly provider = 'google_ai_studio' as const;

  async generate(
    request: UnifiedChatRequest,
    config: LlmRuntimeConfig
  ): Promise<UnifiedChatResponse> {
    const model = request.model || config.defaultModel;
    const response = await axios.post(
      `${stripTrailingSlash(config.baseUrl)}/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        contents: request.messages
          .filter((m) => m.role !== 'system')
          .map((m) => ({
            role: m.role === 'assistant' ? 'model' : 'user',
            parts: [{ text: m.content }],
          })),
        systemInstruction: buildSystemInstruction(request.messages),
        generationConfig: {
          temperature: request.temperature,
          maxOutputTokens: request.maxTokens,
        },
      },
      {
        params: { key: config.apiKey },
      }
    );

    return {
      provider: this.provider,
      model,
      text: extractGeminiText(response.data),
    };
  }
}

function buildSystemInstruction(messages: UnifiedChatRequest['messages']) {
  const text = messages
    .filter((m) => m.role === 'system')
    .map((m) => m.content.trim())
    .filter(Boolean)
    .join('\n\n');
  if (!text) return undefined;
  return {
    role: 'system',
    parts: [{ text }],
  };
}

function extractGeminiText(data: unknown): string {
  if (!data || typeof data !== 'object') return '';
  const candidates = (data as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return '';
  const first = candidates[0] as { content?: { parts?: Array<{ text?: string }> } };
  const parts = first.content?.parts ?? [];
  return parts
    .map((part) => part.text)
    .filter((text): text is string => typeof text === 'string')
    .join('');
}

function stripTrailingSlash(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}
