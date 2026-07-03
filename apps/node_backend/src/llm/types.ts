import type { LanguageModel } from 'ai';

export type LlmProvider = 'anthropic' | 'google_ai_studio';

export interface UnifiedMessage {
  role: 'system' | 'user' | 'assistant';
  content: UnifiedMessageContent;
}

export type UnifiedMessageContent = string | UnifiedMessagePart[];

export type UnifiedMessagePart =
  | { type: 'text'; text: string }
  | { type: 'image'; image: Uint8Array; mediaType: string };

export interface UnifiedChatRequest {
  model?: string;
  configId?: string;
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
  createModel(modelId: string, config: LlmRuntimeConfig): LanguageModel;
}

/**
 * A single agent tool definition. The `parametersSchema` is a JSON Schema
 * object describing the tool's input. The `execute` function receives args
 * matching that schema and returns an arbitrary result.
 */
export interface AgentTool {
  description: string;
  parametersSchema: Record<string, unknown>;
  execute: (args: Record<string, unknown>) => Promise<unknown>;
}

/**
 * The result of one tool call within an agent-loop step.
 */
export interface AgentLoopStepResult {
  toolName: string;
  args: Record<string, unknown>;
  result: unknown;
}
