export type LlmProvider = 'anthropic' | 'google_ai_studio';

export interface UnifiedMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface UnifiedChatRequest {
  model?: string;
  messages: UnifiedMessage[];
  temperature?: number;
  maxTokens?: number;
}

export interface UnifiedChatResponse {
  provider: LlmProvider;
  model: string;
  text: string;
}

export interface LlmRuntimeConfig {
  provider: LlmProvider;
  baseUrl: string;
  apiKey: string;
  defaultModel: string;
}

export interface LlmProviderAdapter {
  readonly provider: LlmProvider;
  generate(request: UnifiedChatRequest, config: LlmRuntimeConfig): Promise<UnifiedChatResponse>;
}
