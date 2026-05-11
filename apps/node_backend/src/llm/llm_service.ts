import { generateText, streamText, jsonSchema, stepCountIs } from 'ai';
import type { LanguageModel } from 'ai';
import { getApiConfigs } from '../services/configService.js';
import { AnthropicAdapter } from './providers/anthropic_adapter.js';
import { GoogleAiStudioAdapter } from './providers/google_ai_studio_adapter.js';
import {
  LlmProvider,
  LlmProviderAdapter,
  LlmRuntimeConfig,
  UnifiedChatRequest,
  UnifiedChatResponse,
  AgentTool,
  AgentLoopStepResult,
} from './types.js';

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
  const runtimeConfig = await resolveRuntimeConfig(
    userId,
    preferredProvider,
    request.configId
  );
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
  const runtimeConfig = await resolveRuntimeConfig(
    userId,
    preferredProvider,
    request.configId
  );
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
  preferredProvider?: LlmProvider,
  preferredConfigId?: string
): Promise<LlmRuntimeConfig> {
  const allConfigs = (await getApiConfigs(userId, 'llm')) as StoredLlmConfig[];
  if (allConfigs.length === 0) {
    throw new Error('No LLM configuration found for user');
  }

  const selected =
    (preferredConfigId
      ? allConfigs.find((cfg) => cfg.id === preferredConfigId)
      : undefined) ??
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

/**
 * Converts our neutral AgentTool map into the AI SDK tool format.
 * Uses jsonSchema() so that zod is not required.
 */
function buildAiSdkTools(tools: Record<string, AgentTool>): Record<string, unknown> {
  const sdkTools: Record<string, unknown> = {};
  for (const [name, agentTool] of Object.entries(tools)) {
    sdkTools[name] = {
      description: agentTool.description,
      parameters: jsonSchema(agentTool.parametersSchema),
      execute: agentTool.execute,
    };
  }
  return sdkTools;
}

/**
 * Shape of an individual tool result entry in an `OnStepFinishEvent`.
 * We define this locally to avoid importing the SDK's generic `TypedToolResult`
 * which requires knowing the full ToolSet type at compile time.
 */
interface SdkToolResult {
  toolName: string;
  args: unknown;
  result: unknown;
}

/**
 * Minimal subset of the AI SDK `OnStepFinishEvent` we consume.
 */
interface SdkStepFinishEvent {
  toolResults?: SdkToolResult[];
}

/**
 * Minimal subset of a completed AI SDK step, used only by our custom
 * `stopWhen` condition that counts cumulative tool calls. The full SDK
 * `StepResult` type is deeply generic and would require importing the
 * ToolSet type parameter — `toolResults` is the only field we need.
 */
interface SdkStepSummary {
  toolResults?: unknown[];
}

/**
 * A synchronous stop condition compatible with the AI SDK `stopWhen` parameter.
 * The SDK's `StopCondition<TOOLS>` generic type requires knowing the ToolSet at
 * compile time; we use this local alias with a known-safe shape instead.
 */
type AgentStopCondition = (event: { steps?: SdkStepSummary[] }) => boolean;

/** Maximum wall-clock timeout we allow for a single agent-loop invocation (ms). */
const MAX_AGENT_TIMEOUT_MS = 120_000;

/**
 * Streams a model-driven agent loop that can call internal tools.
 *
 * The AI model decides which tools (if any) to invoke. Each completed step
 * that contains tool results fires `onStepFinish` so that the caller can
 * persist intermediate tool-call messages. The returned `textStream` carries
 * only the model's final text response.
 *
 * @param options.maxSteps     - Hard upper bound on the number of LLM call steps.
 * @param options.maxToolCalls - Optional cap on the cumulative number of tool calls
 *   across all steps. Evaluated after each step finishes; stops before the next
 *   step once the cumulative total reaches this limit.
 * @param options.timeoutMs    - Optional wall-clock timeout (ms), clamped to
 *   MAX_AGENT_TIMEOUT_MS. The stream is aborted via AbortController when
 *   triggered; the caller receives an AbortError from the text-stream iterator.
 */
export async function streamWithAgentToolsAndUserConfig(
  userId: string,
  request: UnifiedChatRequest,
  tools: Record<string, AgentTool>,
  options: {
    maxSteps: number;
    maxToolCalls?: number;
    timeoutMs?: number;
    onStepFinish?: (stepResults: AgentLoopStepResult[]) => Promise<void>;
  },
  preferredProvider?: LlmProvider,
): Promise<{ textStream: AsyncIterable<string>; provider: LlmProvider; modelId: string }> {
  const runtimeConfig = await resolveRuntimeConfig(userId, preferredProvider, request.configId);
  const { model, modelId } = resolveModel(request, runtimeConfig);
  const sdkTools = buildAiSdkTools(tools);

  // Build stop conditions: always enforce maxSteps; also enforce maxToolCalls when set.
  // stopWhen is evaluated AFTER each step completes, so `>= limit` means "the budget
  // was spent in the step that just finished — don't start another step."
  const stopConditions: AgentStopCondition[] = [
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    stepCountIs(options.maxSteps) as any,
  ];
  if (options.maxToolCalls !== undefined) {
    const limit = options.maxToolCalls;
    stopConditions.push((event) => {
      const total = (event.steps ?? []).reduce(
        (sum, step) => sum + (step.toolResults?.length ?? 0),
        0,
      );
      return total >= limit;
    });
  }

  // Set up AbortController for the timeout. Clamp to MAX_AGENT_TIMEOUT_MS so
  // a caller cannot schedule an unbounded timer from user-supplied input.
  const abortController = new AbortController();
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  if (options.timeoutMs && options.timeoutMs > 0) {
    const safeTimeoutMs = Math.min(options.timeoutMs, MAX_AGENT_TIMEOUT_MS);
    timeoutHandle = setTimeout(() => abortController.abort(), safeTimeoutMs);
  }

  // The tools object is typed with generics in the AI SDK but our neutral
  // AgentTool format is compatible at runtime — cast is safe here.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const result = streamText({
    model,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tools: sdkTools as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    stopWhen: stopConditions as any,
    abortSignal: abortController.signal,
    messages: request.messages.map((m) => ({ role: m.role, content: m.content })),
    temperature: request.temperature,
    maxOutputTokens: request.maxTokens ?? 1024,
    // The onStepFinish callback shape changed in AI SDK v6; cast the event to
    // our local interface to access toolResults without pulling in the full
    // generic ToolSet type.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    onStepFinish: options.onStepFinish
      ? (async (event: SdkStepFinishEvent) => {
          const results: AgentLoopStepResult[] = (event.toolResults ?? []).map((tr) => ({
            toolName: String(tr.toolName ?? ''),
            args: (tr.args && typeof tr.args === 'object' && !Array.isArray(tr.args))
              ? (tr.args as Record<string, unknown>)
              : {},
            result: tr.result,
          }));
          if (results.length > 0) {
            await options.onStepFinish!(results);
          }
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        }) as any
      : undefined,
  });

  // Wrap the textStream in a generator that always clears the timeout handle
  // when the stream finishes (naturally or via an error/abort).
  async function* managedStream(): AsyncIterable<string> {
    try {
      yield* result.textStream;
    } finally {
      if (timeoutHandle !== undefined) {
        clearTimeout(timeoutHandle);
      }
    }
  }

  return { textStream: managedStream(), provider: runtimeConfig.provider, modelId };
}
