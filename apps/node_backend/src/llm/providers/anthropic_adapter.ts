import axios from 'axios';
import { LlmProviderAdapter, LlmRuntimeConfig, UnifiedChatRequest, UnifiedChatResponse } from '../types.js';

const DEFAULT_ANTHROPIC_VERSION = '2023-06-01';

export class AnthropicAdapter implements LlmProviderAdapter {
  readonly provider = 'anthropic' as const;

  async generate(
    request: UnifiedChatRequest,
    config: LlmRuntimeConfig
  ): Promise<UnifiedChatResponse> {
    const systemMessages = request.messages
      .filter((m) => m.role === 'system')
      .map((m) => m.content.trim())
      .filter(Boolean);

    const chatMessages = request.messages
      .filter((m) => m.role !== 'system')
      .map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: m.content,
      }));

    const response = await axios.post(
      `${stripTrailingSlash(config.baseUrl)}/v1/messages`,
      {
        model: request.model || config.defaultModel,
        max_tokens: request.maxTokens ?? 1024,
        temperature: request.temperature,
        system: systemMessages.length > 0 ? systemMessages.join('\n\n') : undefined,
        messages: chatMessages,
      },
      {
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': process.env.ANTHROPIC_VERSION || DEFAULT_ANTHROPIC_VERSION,
          'content-type': 'application/json',
        },
      }
    );

    const text = extractAnthropicText(response.data);
    return {
      provider: this.provider,
      model: request.model || config.defaultModel,
      text,
    };
  }
}

function extractAnthropicText(data: unknown): string {
  if (!data || typeof data !== 'object') return '';
  const content = (data as { content?: unknown }).content;
  if (!Array.isArray(content)) return '';
  const textBlocks = content
    .map((block) => {
      if (!block || typeof block !== 'object') return '';
      return (block as { text?: unknown }).text;
    })
    .filter((text): text is string => typeof text === 'string');
  return textBlocks.join('');
}

function stripTrailingSlash(url: string): string {
  return url.endsWith('/') ? url.slice(0, -1) : url;
}
