import express, { Response } from "express";
import rateLimit from "express-rate-limit";
import { authenticate, AuthRequest } from "../middleware/auth.js";
import {
  acceptTask,
  forkThread,
  listUserScopes,
  listSessionMessagesForModel,
  syncMessages,
  upsertMessages,
  type AcceptTaskInput,
  type ForkThreadInput,
  type MessageUpsertInput,
} from "../services/chatAsyncTransportService.js";
import {
  buildChatSessionId,
  builtinDefaultNodeRef,
  CHAT_ROUTER_LOCAL,
  CHAT_ROUTER_PLUGIN,
  deleteChatScopeSetting,
  listChatScopeSettings,
  normalizeChatRouterValue,
  resolveChatScopeRouting,
  resolveScopeInstructions,
  type ChatRouter,
  type ChatScopeType,
  upsertChatScopeSetting,
} from "../services/chatRouterService.js";
import {
  archiveChatChannel,
  claimFirstMessageGeneratedNameAttempt,
  completeFirstMessageGeneratedName,
  insertFirstMessageExactNameIfMissing,
  listChatChannels,
  upsertChatChannel,
} from "../services/chatChannelService.js";
import {
  getPlatformNodeByNodeId,
  listPlatformNodes,
} from "../services/platformNodeService.js";
import {
  generateWithUserConfig,
  streamWithAgentToolsAndUserConfig,
  type AgentLoopStreamStopInfo,
} from "../llm/llm_service.js";
import {
  buildAgentTools,
} from "../services/localAgentLoopService.js";
import {
  listMediaAssetsForUser,
  mediaAssetToDto,
  type MediaAsset,
} from "../services/mediaService.js";
import type { AgentLoopStepResult, LlmProvider } from "../llm/types.js";
import { parseMaxTokens } from "./validation.js";

const router = express.Router();
router.use(authenticate);

const CHAT_SYNC_WINDOW_MS = 60 * 1000;
const CHAT_SYNC_MAX_REQUESTS_PER_WINDOW = 120;
const CHAT_RESPOND_WINDOW_MS = 60 * 1000;
const CHAT_RESPOND_MAX_REQUESTS_PER_WINDOW = 120;
// SSE events endpoint: limit how many new SSE connections can be opened per
// user/session per minute to prevent connection floods.
const CHAT_EVENTS_WINDOW_MS = 60 * 1000;
const CHAT_EVENTS_MAX_CONNECTIONS_PER_WINDOW = 10;
// Interval between each poll of syncMessages while an SSE connection is open.
const CHAT_EVENTS_POLL_INTERVAL_MS = 1000;
// Interval between keep-alive heartbeat comments sent over the SSE stream.
const CHAT_EVENTS_HEARTBEAT_INTERVAL_MS = 15000;
const MAX_ASSISTANT_STREAM_OUTPUT_CHARS = 120 * 1024;
// Minimum interval between incremental DB flushes during model streaming to avoid write amplification.
const STREAM_FLUSH_INTERVAL_MS = 300;
const DEFAULT_INTERNAL_LOOP_MAX_STEPS = 10;
const DEFAULT_INTERNAL_LOOP_MAX_TOOL_CALLS = 50;
const DEFAULT_INTERNAL_LOOP_TIMEOUT_MS = 60000;
const MAX_AUTO_THREAD_NAME_CHARS = 80;
const AUTO_THREAD_TITLE_GENERATION_TIMEOUT_MS = 20_000;

type ChatClientInvalidation =
  | { kind: "chat.scopes"; channelId?: string; threadId?: string | null }
  | { kind: "chat.channelNames"; channelId: string; threadId?: string | null }
  | { kind: "chat.scopeSettings"; channelId?: string; threadId?: string | null }
  | { kind: "resources.todoLists"; listId?: string }
  | { kind: "resources.todos"; listId: string; todoId?: string }
  | { kind: "resources.tables"; resourceId?: string }
  | { kind: "resources.tableColumns"; resourceId: string; columnKey?: string }
  | { kind: "resources.tableRows"; resourceId: string; rowId?: string }
  | { kind: "resources.notes"; noteId?: string };

function readStringField(
  record: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = record[key];
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function toolResultSucceeded(result: unknown): boolean {
  return isRecord(result) && result.ok === true;
}

function invalidationsForToolResult(
  stepResult: AgentLoopStepResult,
): ChatClientInvalidation[] {
  if (!toolResultSucceeded(stepResult.result)) return [];

  const args = stepResult.args;
  const resultData = isRecord(stepResult.result)
    ? isRecord(stepResult.result.data)
      ? stepResult.result.data
      : {}
    : {};
  const channelId = readStringField(args, "channelId") ?? readStringField(resultData, "channelId");
  const threadId = readStringField(args, "threadId") ?? readStringField(resultData, "threadId");
  const listId = readStringField(args, "listId") ?? readStringField(resultData, "listId");
  const todoId = readStringField(args, "id") ?? readStringField(resultData, "id");
  const resourceId = readStringField(args, "resourceId") ?? readStringField(resultData, "resourceId");
  const columnKey = readStringField(args, "columnKey") ?? readStringField(resultData, "columnKey");
  const rowId = readStringField(args, "rowId") ?? readStringField(resultData, "rowId");
  const noteId = readStringField(args, "noteId") ?? readStringField(resultData, "id");

  switch (stepResult.toolName) {
    case "chat_channel_create":
      if (!channelId) return [];
      return [
        { kind: "chat.channelNames", channelId, threadId: null },
        { kind: "chat.scopeSettings", channelId, threadId: null },
      ];
    case "chat_thread_create":
      if (!channelId) return [];
      return [
        {
          kind: "chat.channelNames",
          channelId,
          ...(threadId ? { threadId } : {}),
        },
        {
          kind: "chat.scopeSettings",
          channelId,
          ...(threadId ? { threadId } : {}),
        },
      ];
    case "chat_channel_instruction_set":
      return [
        {
          kind: "chat.scopeSettings",
          ...(channelId ? { channelId } : {}),
          threadId: null,
        },
      ];
    case "chat_thread_instruction_set":
      return [
        {
          kind: "chat.scopeSettings",
          ...(channelId ? { channelId } : {}),
          ...(threadId ? { threadId } : {}),
        },
      ];
    case "chat_channel_rename":
      return channelId
        ? [{ kind: "chat.channelNames", channelId, threadId: null }]
        : [];
    case "todolist_create":
    case "todolist_update":
    case "todolist_delete":
      return [{ kind: "resources.todoLists", ...(listId ? { listId } : {}) }];
    case "todo_create":
    case "todo_complete":
    case "todo_update":
    case "todo_delete":
      return listId
        ? [
            {
              kind: "resources.todos",
              listId,
              ...(todoId ? { todoId } : {}),
            },
          ]
        : [];
    case "table_create":
      return [{ kind: "resources.tables", ...(resourceId ? { resourceId } : {}) }];
    case "table_add_column":
    case "table_remove_column":
      return resourceId
        ? [
            {
              kind: "resources.tableColumns",
              resourceId,
              ...(columnKey ? { columnKey } : {}),
            },
          ]
        : [];
    case "table_add_row":
    case "table_update_row":
    case "table_delete_row":
      return resourceId
        ? [
            {
              kind: "resources.tableRows",
              resourceId,
              ...(rowId ? { rowId } : {}),
            },
        ]
        : [];
    case "note_create":
    case "note_update":
    case "note_delete":
    case "note_append_lines":
    case "note_replace_lines":
    case "note_delete_lines":
      return [{ kind: "resources.notes", ...(noteId ? { noteId } : {}) }];
    default:
      return [];
  }
}

function dedupeInvalidations(
  invalidations: ChatClientInvalidation[],
): ChatClientInvalidation[] {
  const seen = new Set<string>();
  const result: ChatClientInvalidation[] = [];
  for (const invalidation of invalidations) {
    const key = JSON.stringify(invalidation);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(invalidation);
  }
  return result;
}

function isAutoNameEligibleThread(threadId: string | null | undefined): threadId is string {
  const normalized = threadId?.trim();
  return Boolean(normalized && normalized.length > 0 && normalized !== "main");
}

function cleanAutoThreadName(value: string, maxChars = MAX_AUTO_THREAD_NAME_CHARS): string {
  const cleaned = value
    .replace(/\s+/g, " ")
    .replace(/^["'`“”‘’]+|["'`“”‘’]+$/g, "")
    .trim();
  if (cleaned.length <= maxChars) return cleaned;
  return cleaned.slice(0, maxChars).trimEnd();
}

function deriveFallbackGeneratedThreadName(value: string): string {
  const cleaned = cleanAutoThreadName(value);
  if (!cleaned) return "";
  const words = cleaned.split(/\s+/).filter(Boolean);
  if (words.length <= 6) return cleaned;
  return words.slice(0, 6).join(" ");
}

async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  message: string,
): Promise<T> {
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => reject(new Error(message)), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    if (timeoutHandle !== undefined) clearTimeout(timeoutHandle);
  }
}

async function insertFirstMessageExactThreadName(params: {
  userId: string;
  channelId: string;
  threadId: string | null;
  userMessage: string;
}): Promise<ChatClientInvalidation[]> {
  if (!isAutoNameEligibleThread(params.threadId)) return [];
  const displayName = cleanAutoThreadName(params.userMessage);
  if (!displayName) return [];
  const inserted = await insertFirstMessageExactNameIfMissing(params.userId, {
    channelId: params.channelId,
    threadId: params.threadId,
    displayName,
  });
  return inserted
    ? [
        {
          kind: "chat.channelNames",
          channelId: params.channelId,
          threadId: params.threadId,
        },
      ]
    : [];
}

async function generateFirstMessageThreadTitle(params: {
  userId: string;
  channelId: string;
  threadId: string | null;
  body: Record<string, unknown>;
}): Promise<string | null> {
  if (!isAutoNameEligibleThread(params.threadId)) return null;
  const claimed = await claimFirstMessageGeneratedNameAttempt(params.userId, {
    channelId: params.channelId,
    threadId: params.threadId,
  });
  if (!claimed) return null;

  const exactName = claimed.displayName.trim();
  if (!exactName) return null;

  let displayName = "";
  try {
    const response = await withTimeout(
      generateWithUserConfig(
        params.userId,
        {
          model:
            typeof params.body.model === "string" ? params.body.model : undefined,
          configId:
            typeof params.body.configId === "string"
              ? params.body.configId
              : undefined,
          temperature: 0.2,
          maxTokens: 64,
          messages: [
            {
              role: "system",
              content:
                "Generate a concise chat thread title from the user's first message. " +
                "Return only the title. Use the same language as the user's message. " +
                "Do not use quotes, markdown, punctuation-only titles, or explanations. " +
                "Keep it under 8 words.",
            },
            {
              role: "user",
              content: exactName,
            },
          ],
        },
        parseProvider(params.body.provider),
      ),
      AUTO_THREAD_TITLE_GENERATION_TIMEOUT_MS,
      `Auto thread title generation timed out after ${AUTO_THREAD_TITLE_GENERATION_TIMEOUT_MS}ms`,
    );
    displayName = cleanAutoThreadName(response.text);
  } catch (error) {
    console.warn(
      "Auto thread title model generation failed, using fallback:",
      error instanceof Error ? error.message : String(error),
    );
  }
  if (!displayName) {
    displayName = deriveFallbackGeneratedThreadName(exactName);
  }
  if (!displayName) return null;
  const updated = await completeFirstMessageGeneratedName(params.userId, {
    channelId: params.channelId,
    threadId: params.threadId,
    displayName,
  });
  return updated ? updated.displayName : null;
}

type AgentLoopStopReasonType =
  | "tool_call_limit_reached"
  | "step_limit_reached"
  | "timeout_reached"
  | "stream_error"
  | "empty_final_after_tool_calls";

function classifyEmptyFinalStopReason(params: {
  totalToolCallCount: number;
  loopMaxToolCalls: number;
  toolStepIndex: number;
  loopMaxSteps: number;
  streamStopInfo: AgentLoopStreamStopInfo | null;
}): {
  type: AgentLoopStopReasonType;
  message: string;
  details: Record<string, unknown>;
} {
  const {
    totalToolCallCount,
    loopMaxToolCalls,
    toolStepIndex,
    loopMaxSteps,
    streamStopInfo,
  } = params;

  if (loopMaxToolCalls > 0 && totalToolCallCount >= loopMaxToolCalls) {
    return {
      type: "tool_call_limit_reached",
      message:
        `The assistant stopped before producing a final answer because the internal ` +
        `tool-call limit was reached (${totalToolCallCount}/${loopMaxToolCalls}). ` +
        `Please retry, narrow the request, or increase the tool-call budget.`,
      details: {},
    };
  }

  if (toolStepIndex >= loopMaxSteps) {
    return {
      type: "step_limit_reached",
      message:
        `The assistant stopped before producing a final answer because the internal ` +
        `agent-loop step limit was reached (${toolStepIndex}/${loopMaxSteps}). ` +
        `Please retry, narrow the request, or increase the step budget.`,
      details: {},
    };
  }

  if (streamStopInfo?.type === "timeout_reached") {
    return {
      type: "timeout_reached",
      message:
        `The assistant stopped before producing a final answer because the internal ` +
        `agent-loop step timeout was reached (${streamStopInfo.timeoutMs}ms). ` +
        `Please retry or narrow the request.`,
      details: {
        timeoutMs: streamStopInfo.timeoutMs,
        timeoutStepIndex: streamStopInfo.stepIndex,
      },
    };
  }

  if (streamStopInfo?.type === "stream_error") {
    return {
      type: "stream_error",
      message:
        `The assistant stopped before producing a final answer because the model ` +
        `stream ended with an error. Please retry or narrow the request.`,
      details: {
        errorName: streamStopInfo.errorName,
        errorMessage: streamStopInfo.errorMessage,
        errorStepIndex: streamStopInfo.stepIndex,
      },
    };
  }

  return {
    type: "empty_final_after_tool_calls",
    message:
      `The assistant completed tool calls but did not produce a final answer. ` +
      `Please retry or narrow the request.`,
    details:
      streamStopInfo?.type === "sdk_finish"
        ? {
            sdkFinishReason: streamStopInfo.finishReason,
            sdkFinishStepIndex: streamStopInfo.stepIndex,
          }
        : {},
  };
}

function parseBoundedInt(
  value: unknown,
  defaults: { fallback: number; min: number; max: number },
): number {
  const parsed =
    typeof value === "number"
      ? Math.trunc(value)
      : typeof value === "string"
        ? Number.parseInt(value, 10)
        : Number.NaN;
  if (!Number.isFinite(parsed)) return defaults.fallback;
  return Math.max(defaults.min, Math.min(defaults.max, parsed));
}

function formatToolExecutionError(error: unknown): { code: string; message: string } {
  if (error instanceof Error) {
    return { code: error.name || "tool_execution_error", message: error.message };
  }
  if (error && typeof error === "object" && "message" in error) {
    const message = (error as { message?: unknown }).message;
    return {
      code: "tool_execution_error",
      message: typeof message === "string" ? message : String(error),
    };
  }
  return { code: "tool_execution_error", message: String(error) };
}

function dispatchPlaceholderMetadata(params: {
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
  source: string;
  model?: string | null;
  agentName?: string | null;
}) {
  const metadata: {
    resolvedBotId: string | null;
    resolvedSkillId: string | null;
    source: string;
    dispatchPlaceholder: true;
    model?: string;
    agentName?: string;
  } = {
    resolvedBotId: params.resolvedBotId,
    resolvedSkillId: params.resolvedSkillId,
    source: params.source,
    dispatchPlaceholder: true,
  };

  if (typeof params.model === "string" && params.model.trim() !== "") {
    metadata.model = params.model;
  }

  if (
    typeof params.agentName === "string" &&
    params.agentName.trim() !== ""
  ) {
    metadata.agentName = params.agentName;
  }

  return metadata;
}

async function emitAssistantDispatchPlaceholder(params: {
  userId: string;
  assistantMessageId: string;
  acceptedTaskId: string;
  acceptedSessionId: string;
  channelId: string;
  threadId: string | null;
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
  source: string;
  model?: string | null;
  agentName?: string | null;
}) {
  await upsertMessages(params.userId, [
    {
      messageId: params.assistantMessageId,
      taskId: params.acceptedTaskId,
      channelId: params.channelId,
      sessionId: params.acceptedSessionId,
      threadId: params.threadId,
      role: "assistant",
      content: "",
      taskState: "dispatched",
      checkpointCursor: null,
      metadata: dispatchPlaceholderMetadata({
        resolvedBotId: params.resolvedBotId,
        resolvedSkillId: params.resolvedSkillId,
        source: params.source,
        model: params.model,
        agentName: params.agentName,
      }),
      createdAt: null,
    },
  ]);
}

function parseSessionId(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > 255) return null;
  return trimmed;
}

function parseNonNegativeInt(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 0) return null;
  return parsed;
}

function parseProvider(value: unknown): LlmProvider | undefined {
  if (value === "anthropic" || value === "google_ai_studio") return value;
  if (value === "gemini") return "google_ai_studio";
  return undefined;
}

function parseChatRouter(value: unknown): ChatRouter | null {
  return typeof value === "string" ? normalizeChatRouterValue(value) : null;
}

function parseMediaAttachmentIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const ids: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    const mediaId =
      typeof item === "string"
        ? item.trim()
        : isRecord(item) && typeof item.mediaId === "string"
          ? item.mediaId.trim()
          : isRecord(item) && typeof item.id === "string"
            ? item.id.trim()
            : "";
    if (!mediaId || seen.has(mediaId)) continue;
    seen.add(mediaId);
    ids.push(mediaId);
  }
  return ids.slice(0, 10);
}

function mediaAttachmentsMetadata(assets: MediaAsset[]) {
  return assets.map((asset) => mediaAssetToDto(asset));
}

function parseScopeType(value: unknown): ChatScopeType | null {
  if (value === "channel" || value === "thread") return value;
  return null;
}

function chatSessionRateLimitKey(
  req: express.Request,
  sessionId: string,
): string {
  const userId =
    typeof (req as AuthRequest).userId === "string"
      ? (req as AuthRequest).userId
      : "anonymous";
  return `${userId}:${sessionId}`;
}

const syncLimiter = rateLimit({
  windowMs: CHAT_SYNC_WINDOW_MS,
  max: CHAT_SYNC_MAX_REQUESTS_PER_WINDOW,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const sessionId = parseSessionId(req.params.sessionId) ?? "invalid-session";
    return chatSessionRateLimitKey(req, sessionId);
  },
  message: {
    error:
      "Too many sync requests for this chat session, please try again later.",
  },
});

const eventsLimiter = rateLimit({
  windowMs: CHAT_EVENTS_WINDOW_MS,
  max: CHAT_EVENTS_MAX_CONNECTIONS_PER_WINDOW,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const sessionId = parseSessionId(req.params.sessionId) ?? "invalid-session";
    return chatSessionRateLimitKey(req, sessionId);
  },
  message: {
    error:
      "Too many SSE connection attempts for this chat session, please try again later.",
  },
});


const respondLimiter = rateLimit({
  windowMs: CHAT_RESPOND_WINDOW_MS,
  max: CHAT_RESPOND_MAX_REQUESTS_PER_WINDOW,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const sessionId = parseSessionId(req.body?.sessionId) ?? "invalid-session";
    return chatSessionRateLimitKey(req, sessionId);
  },
  message: {
    error:
      "Too many respond requests for this chat session, please try again later.",
  },
});

/**
 * Builds a composed system prompt from the agent system prompt and optional
 * scope instructions (channel-level and, when in a sub-section, thread-level).
 *
 * Returns null when there is nothing to include so that callers can skip
 * adding a system message entirely.
 */
function buildComposedSystemPrompt(params: {
  systemPrompt: string | null;
  channelInstructions: string | null;
  threadInstructions: string | null;
  channelId: string;
  threadId: string | null;
}): string | null {
  const parts: string[] = [];

  // Inject session context so the LLM knows the internal channel/thread IDs it
  // must pass to tools like chat_channel_rename, chat_channel_instruction_set, etc.
  const ctxParts: string[] = [`Channel ID: ${params.channelId}`];
  if (params.threadId && params.threadId !== 'main') {
    ctxParts.push(`Thread ID: ${params.threadId}`);
  }
  parts.push(`Session context:\n${ctxParts.map((l) => `- ${l}`).join('\n')}`);

  const sp = params.systemPrompt?.trim();
  if (sp) parts.push(sp);

  const ci = params.channelInstructions?.trim();
  if (ci) parts.push(`Channel context:\n${ci}`);

  const ti = params.threadInstructions?.trim();
  if (ti) parts.push(`Section context:\n${ti}`);

  return parts.length > 0 ? parts.join('\n\n') : null;
}

async function runDefaultRouterRespondAsync(params: {
  userId: string;
  acceptedTaskId: string;
  acceptedSessionId: string;
  assistantMessageId: string;
  channelId: string;
  threadId: string | null;
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
  userMessage: string;
  body: Record<string, unknown>;
  maxTokens: number;
  systemPrompt: string | null;
  channelInstructions: string | null;
  threadInstructions: string | null;
}) {
  const {
    userId,
    acceptedTaskId,
    acceptedSessionId,
    assistantMessageId,
    channelId,
    threadId,
    resolvedBotId,
    resolvedSkillId,
    userMessage,
    body,
    maxTokens,
    systemPrompt,
    channelInstructions,
    threadInstructions,
  } = params;

  // NOTE: This runs after the HTTP response has been sent. On Vercel Serverless
  // Functions the runtime may freeze the invocation once the response is sent,
  // so this work is not guaranteed to complete. A durable background job/queue
  // (or platform-provided waitUntil) would be needed for production reliability.
  try {
    await emitAssistantDispatchPlaceholder({
      userId,
      assistantMessageId,
      acceptedTaskId,
      acceptedSessionId,
      channelId,
      threadId,
      resolvedBotId,
      resolvedSkillId,
      source: "backend.respond.stream",
      model: typeof body.model === "string" ? body.model : null,
    });

    const loopMaxSteps = parseBoundedInt(body.maxSteps, {
      fallback: DEFAULT_INTERNAL_LOOP_MAX_STEPS,
      min: 1,
      max: 12,
    });
    const loopMaxToolCalls = parseBoundedInt(body.maxToolCalls, {
      fallback: DEFAULT_INTERNAL_LOOP_MAX_TOOL_CALLS,
      min: 1,
      max: 50,
    });
    const loopTimeoutMs = parseBoundedInt(body.timeoutMs, {
      fallback: DEFAULT_INTERNAL_LOOP_TIMEOUT_MS,
      min: 1000,
      max: 120000,
    });

    const modelMessages = await listSessionMessagesForModel(userId, acceptedSessionId, {
      limit: 40,
      maxChars: 10000,
    });

    const composedSystemPrompt = buildComposedSystemPrompt({
      systemPrompt,
      channelInstructions,
      threadInstructions,
      channelId,
      threadId,
    });
    const messagesWithSystem = composedSystemPrompt
      ? [{ role: 'system' as const, content: composedSystemPrompt }, ...modelMessages]
      : modelMessages;

    let textStream: AsyncIterable<string>;
    let provider: string;
    let modelId: string;
    let getStreamStopInfo: () => AgentLoopStreamStopInfo | null = () => null;
    let toolStepIndex = 0;
    let completedToolCallCount = 0;
    let failedToolCallCount = 0;
    const collectedInvalidations: ChatClientInvalidation[] = [];
    try {
      collectedInvalidations.push(
        ...(await insertFirstMessageExactThreadName({
          userId,
          channelId,
          threadId,
          userMessage,
        })),
      );
    } catch (error) {
      console.warn("Failed to persist exact thread name; continuing chat response", {
        userId,
        channelId,
        threadId,
        error,
      });
    }

    // Always use the agent-loop path so the model is aware of (and can invoke)
    // internal tools regardless of whether the user typed a slash command or
    // plain natural language.  The managedStream generator yields text deltas
    // eagerly for tool-free steps, so streaming UX is equivalent to the direct
    // streamWithUserConfig path for ordinary chat messages.
    const agentTools = buildAgentTools(userId);
    const streamResult = await streamWithAgentToolsAndUserConfig(
        userId,
        {
          model: typeof body.model === "string" ? body.model : undefined,
          configId: typeof body.configId === "string" ? body.configId : undefined,
          messages: messagesWithSystem,
          maxTokens,
        },
        agentTools,
        {
          maxSteps: loopMaxSteps,
          maxToolCalls: loopMaxToolCalls,
          timeoutMs: loopTimeoutMs,
          onStepFinish: async (stepResults) => {
            toolStepIndex++;
            completedToolCallCount += stepResults.length;
            const stepInvalidations = dedupeInvalidations(
              stepResults.flatMap(invalidationsForToolResult),
            );
            collectedInvalidations.push(...stepInvalidations);
            const stepSuffix = `:ts:${toolStepIndex}`;
            const stepMessageId = `${assistantMessageId.slice(0, 255 - stepSuffix.length)}${stepSuffix}`;
            const stepContent = stepResults
              .map((stepResult) => `**Tool:** \`${stepResult.toolName}\`\n\`\`\`json\n${JSON.stringify(stepResult.result, null, 2)}\n\`\`\``)
              .join('\n\n');
            await upsertMessages(userId, [
              {
                messageId: stepMessageId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: stepContent,
                taskState: 'dispatched',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'tool_call',
                    stepIndex: toolStepIndex,
                    completedCalls: stepResults.length,
                    maxSteps: loopMaxSteps,
                    maxToolCalls: loopMaxToolCalls,
                    timeoutMs: loopTimeoutMs,
	                  },
	                  toolCalls: stepResults,
	                  ...(stepInvalidations.length > 0
	                    ? { invalidations: stepInvalidations }
	                    : {}),
	                },
	                createdAt: null,
	              },
            ]);

            // Mark each :tc (tool_call_start) message for this step as completed
            // now that the tool call has finished executing.  Since onToolCallStart
            // is awaited (not fire-and-forget), these messages are guaranteed to
            // exist in the DB before we reach this point.
            for (let ci = 0; ci < stepResults.length; ci++) {
              const tcSuffix = `:tc:${toolStepIndex}:${ci}`;
              const tcMsgId = `${assistantMessageId.slice(0, 255 - tcSuffix.length)}${tcSuffix}`;
              await upsertMessages(userId, [
                {
                  messageId: tcMsgId,
                  taskId: acceptedTaskId,
                  channelId,
                  sessionId: acceptedSessionId,
                  threadId,
                  role: 'assistant',
                  content: '',
                  taskState: 'completed',
                  checkpointCursor: null,
                  metadata: {
                    ...dispatchPlaceholderMetadata({
                      resolvedBotId,
                      resolvedSkillId,
                      source: 'backend.respond.agent_loop',
                      model: typeof body.model === 'string' ? body.model : null,
                    }),
                    agentLoop: {
                      phase: 'tool_call_start',
                      stepIndex: toolStepIndex,
                      callIndex: ci,
                      toolName: stepResults[ci].toolName,
                      args: stepResults[ci].args,
                    },
                  },
                  createdAt: null,
                },
              ]);
            }
          },
          onToolCallStart: async (toolName, args, stepIndex, callIndex) => {
            const suffix = `:tc:${stepIndex + 1}:${callIndex}`;
            const tcMessageId = `${assistantMessageId.slice(0, 255 - suffix.length)}${suffix}`;
            await upsertMessages(userId, [
              {
                messageId: tcMessageId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: '',
                taskState: 'dispatched',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'tool_call_start',
                    stepIndex: stepIndex + 1,
                    callIndex,
                    toolName,
                    args,
                  },
                },
                createdAt: null,
              },
            ]);
          },
          onToolCallError: async (toolName, args, error, stepIndex, callIndex) => {
            failedToolCallCount++;
            const oneBasedStepIndex = stepIndex + 1;
            const toolError = formatToolExecutionError(error);
            const failedResult = {
              ok: false,
              toolName,
              data: null,
              error: toolError,
            };
            const stepSuffix = `:ts:${oneBasedStepIndex}`;
            const stepMessageId = `${assistantMessageId.slice(0, 255 - stepSuffix.length)}${stepSuffix}`;
            const stepContent = `**Tool:** \`${toolName}\`\n\`\`\`json\n${JSON.stringify(failedResult, null, 2)}\n\`\`\``;

            await upsertMessages(userId, [
              {
                messageId: stepMessageId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: stepContent,
                taskState: 'failed',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'tool_call',
                    stepIndex: oneBasedStepIndex,
                    completedCalls: 0,
                    failedCalls: 1,
                    maxSteps: loopMaxSteps,
                    maxToolCalls: loopMaxToolCalls,
                    timeoutMs: loopTimeoutMs,
                  },
                  toolCalls: [
                    {
                      toolName,
                      args,
                      result: failedResult,
                    },
                  ],
                },
                createdAt: null,
              },
            ]);

            const tcSuffix = `:tc:${oneBasedStepIndex}:${callIndex}`;
            const tcMsgId = `${assistantMessageId.slice(0, 255 - tcSuffix.length)}${tcSuffix}`;
            await upsertMessages(userId, [
              {
                messageId: tcMsgId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: '',
                taskState: 'completed',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'tool_call_start',
                    stepIndex: oneBasedStepIndex,
                    callIndex,
                    toolName,
                    args,
                    error: toolError,
                  },
                },
                createdAt: null,
              },
            ]);
          },
          onReasoningChunk: async (text, stepIndex) => {
            const suffix = `:r:${stepIndex + 1}`;
            const rMessageId = `${assistantMessageId.slice(0, 255 - suffix.length)}${suffix}`;
            await upsertMessages(userId, [
              {
                messageId: rMessageId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: text,
                taskState: 'dispatched',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'reasoning',
                    stepIndex: stepIndex + 1,
                  },
                },
                createdAt: null,
              },
            ]);
          },
          onStepTextEnd: async (text, stepIndex) => {
            const suffix = `:pt:${stepIndex + 1}`;
            const ptMessageId = `${assistantMessageId.slice(0, 255 - suffix.length)}${suffix}`;
            await upsertMessages(userId, [
              {
                messageId: ptMessageId,
                taskId: acceptedTaskId,
                channelId,
                sessionId: acceptedSessionId,
                threadId,
                role: 'assistant',
                content: text,
                taskState: 'dispatched',
                checkpointCursor: null,
                metadata: {
                  ...dispatchPlaceholderMetadata({
                    resolvedBotId,
                    resolvedSkillId,
                    source: 'backend.respond.agent_loop',
                    model: typeof body.model === 'string' ? body.model : null,
                  }),
                  agentLoop: {
                    phase: 'step_text',
                    stepIndex: stepIndex + 1,
                  },
                },
                createdAt: null,
              },
            ]);
          },
        },
        parseProvider(body.provider),
      );
    textStream = streamResult.textStream;
    provider = streamResult.provider;
    modelId = streamResult.modelId;
    getStreamStopInfo = streamResult.getStopInfo ?? (() => null);

    let assistantContent = "";
    let hasAnyChunk = false;
    let lastFlushTime = Date.now();
    let lastFlushedContent = "";

    const buildDispatchedUpsert = (content: string): MessageUpsertInput => ({
      messageId: assistantMessageId,
      taskId: acceptedTaskId,
      channelId,
      sessionId: acceptedSessionId,
      threadId,
      role: "assistant",
      content,
      taskState: "dispatched",
      checkpointCursor: null,
      metadata: {
        ...dispatchPlaceholderMetadata({
          resolvedBotId,
          resolvedSkillId,
          source: "backend.respond.stream",
          model: modelId,
        }),
        provider,
        streamMode: "model-chunk",
      },
      createdAt: null,
    });

    const textStreamIterator = textStream[Symbol.asyncIterator]();
    let streamFullyConsumed = false;
    try {
      while (true) {
        const { value: chunk, done } = await textStreamIterator.next();
        if (done) {
          streamFullyConsumed = true;
          break;
        }

        if (typeof chunk !== "string" || chunk.length === 0) {
          continue;
        }
        hasAnyChunk = true;
        if (assistantContent.length >= MAX_ASSISTANT_STREAM_OUTPUT_CHARS) {
          break;
        }

        const remaining = MAX_ASSISTANT_STREAM_OUTPUT_CHARS - assistantContent.length;
        const appendChunk = chunk.length > remaining ? chunk.slice(0, remaining) : chunk;
        assistantContent += appendChunk;

        // Flush to DB at most once per STREAM_FLUSH_INTERVAL_MS to avoid write amplification.
        const now = Date.now();
        if (now - lastFlushTime >= STREAM_FLUSH_INTERVAL_MS) {
          lastFlushTime = now;
          lastFlushedContent = assistantContent;
          await upsertMessages(userId, [buildDispatchedUpsert(assistantContent)]);
        }
      }
    } finally {
      if (!streamFullyConsumed && typeof textStreamIterator.return === "function") {
        try {
          await textStreamIterator.return();
        } catch {
          // Ignore cleanup errors.
        }
      }
    }

    // Always do a final incremental flush for any content not yet persisted.
    if (hasAnyChunk && assistantContent !== lastFlushedContent) {
      await upsertMessages(userId, [buildDispatchedUpsert(assistantContent)]);
    }

    const totalToolCallCount = completedToolCallCount + failedToolCallCount;
    const finalInvalidations = dedupeInvalidations(collectedInvalidations);
    const streamStopInfo = getStreamStopInfo();
    const emptyFinalStopReason =
      assistantContent.trim().length === 0 && totalToolCallCount > 0
        ? classifyEmptyFinalStopReason({
            totalToolCallCount,
            loopMaxToolCalls,
            toolStepIndex,
            loopMaxSteps,
            streamStopInfo,
          })
        : null;
    const finalContent =
      assistantContent.trim().length > 0
        ? assistantContent
        : emptyFinalStopReason != null
          ? emptyFinalStopReason.message
          : assistantContent;
    const finalTaskState =
      assistantContent.trim().length === 0 && totalToolCallCount > 0
        ? "failed"
        : "completed";
    const agentLoopStopReason =
      emptyFinalStopReason != null
        ? {
            type: emptyFinalStopReason.type,
            toolCallCount: totalToolCallCount,
            completedToolCallCount,
            failedToolCallCount,
            maxToolCalls: loopMaxToolCalls,
            stepCount: toolStepIndex,
            maxSteps: loopMaxSteps,
            ...emptyFinalStopReason.details,
          }
        : null;

    await upsertMessages(userId, [
      {
        messageId: assistantMessageId,
        taskId: acceptedTaskId,
        channelId,
        sessionId: acceptedSessionId,
        threadId,
        role: "assistant",
        content: finalContent,
        taskState: finalTaskState,
        checkpointCursor: null,
        metadata: {
          ...dispatchPlaceholderMetadata({
            resolvedBotId,
            resolvedSkillId,
            source: "backend.respond.stream",
            model: modelId,
          }),
          provider,
          streamMode: "model-chunk",
          ...(finalInvalidations.length > 0
            ? { invalidations: finalInvalidations }
            : {}),
          ...(agentLoopStopReason ? { agentLoopStopReason } : {}),
        },
        createdAt: null,
      },
    ]);
    if (finalTaskState === "completed") {
      try {
        const generatedName = await generateFirstMessageThreadTitle({
          userId,
          channelId,
          threadId,
          body,
        });
        if (generatedName) {
          await upsertMessages(userId, [
            {
              messageId: assistantMessageId,
              taskId: acceptedTaskId,
              channelId,
              sessionId: acceptedSessionId,
              threadId,
              role: "assistant",
              content: finalContent,
              taskState: finalTaskState,
              checkpointCursor: null,
              metadata: {
                provider,
                streamMode: "model-chunk",
                invalidations: [
                  ...new Map(
                    [
                      ...finalInvalidations,
                      {
                        kind: "chat.channelNames",
                        channelId,
                        threadId,
                      },
                    ].map((invalidation) => [
                      JSON.stringify(invalidation),
                      invalidation,
                    ]),
                  ).values(),
                ],
                autoThreadName: {
                  source: "first_message_generated",
                  displayName: generatedName,
                },
              },
              createdAt: null,
            },
          ]);
        }
      } catch (error) {
        console.warn(
          "Auto thread title generation failed:",
          error instanceof Error ? error.message : String(error),
        );
      }
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await upsertMessages(userId, [
      {
        messageId: assistantMessageId,
        taskId: acceptedTaskId,
        channelId,
        sessionId: acceptedSessionId,
        threadId,
        role: "assistant",
        content: `Error: ${message}`,
        taskState: "failed",
        checkpointCursor: null,
        metadata: {
          ...dispatchPlaceholderMetadata({
            resolvedBotId,
            resolvedSkillId,
            source: "backend.respond",
            model: typeof body.model === "string" ? body.model : null,
          }),
          error: message,
        },
        createdAt: null,
      },
    ]);
    console.error("Chat default async respond error:", error);
  }
}

router.post(
  "/respond",
  respondLimiter,
  async (req: AuthRequest, res: Response) => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ error: "Unauthorized" });
        return;
      }

      const body = req.body ?? {};
      const taskId = parseSessionId(body.taskId);
      const idempotencyKey = parseSessionId(body.idempotencyKey);
      const channelId = parseSessionId(body.channelId);
      const sessionId = parseSessionId(body.sessionId);
      const threadId = parseSessionId(body.threadId);
      const userMessageId = parseSessionId(body.userMessageId);
      const assistantMessageId = parseSessionId(body.assistantMessageId);
      const userMessage =
        typeof body.userMessage === "string" ? body.userMessage.trim() : "";
      const mediaAttachmentIds = parseMediaAttachmentIds(body.mediaAttachmentIds);
      const mediaAssets =
        mediaAttachmentIds.length > 0
          ? await listMediaAssetsForUser(userId, mediaAttachmentIds)
          : [];
      const mediaById = new Map(mediaAssets.map((asset) => [asset.id, asset]));
      const orderedMediaAssets = mediaAttachmentIds
        .map((mediaId) => mediaById.get(mediaId))
        .filter((asset): asset is MediaAsset => Boolean(asset));
      const hasMissingMedia = orderedMediaAssets.length !== mediaAttachmentIds.length;
      const hasWrongChannelMedia = orderedMediaAssets.some(
        (asset) => asset.channelId !== channelId,
      );
      const parsedMaxTokens = parseMaxTokens(body.maxTokens);

      if (
        !taskId ||
        !idempotencyKey ||
        !channelId ||
        !sessionId ||
        !userMessageId ||
        !assistantMessageId ||
        (!userMessage && orderedMediaAssets.length === 0)
      ) {
        res.status(400).json({
          error:
            "Invalid payload: taskId, idempotencyKey, channelId, sessionId, userMessageId, assistantMessageId, and userMessage or mediaAttachmentIds are required",
        });
        return;
      }

      if (hasMissingMedia || hasWrongChannelMedia) {
        res.status(400).json({
          error: "Invalid payload: all media attachments must exist and belong to the current channel",
        });
        return;
      }

      if (!parsedMaxTokens.ok) {
        res.status(400).json({ error: parsedMaxTokens.error });
        return;
      }

      const input: AcceptTaskInput = {
        taskId,
        idempotencyKey,
        channelId,
        sessionId,
        threadId,
        resolvedBotId: parseSessionId(body.resolvedBotId),
        resolvedSkillId: parseSessionId(body.resolvedSkillId),
      };
      const requestedNodeId = parseSessionId(body.nodeId);
      const resolvedRouting = await resolveChatScopeRouting(userId, {
        channelId,
        threadId,
      });
      let resolvedRouter = resolvedRouting.router;
      let targetNode = null;
      if (resolvedRouter === CHAT_ROUTER_PLUGIN) {
        if (requestedNodeId) {
          targetNode = await getPlatformNodeByNodeId(userId, requestedNodeId);
          if (!targetNode) {
            res.status(400).json({
              error: "Invalid payload: nodeId must reference an existing platform node",
            });
            return;
          }
        } else if (resolvedRouting.nodeId) {
          targetNode = await getPlatformNodeByNodeId(userId, resolvedRouting.nodeId);
          if (!targetNode) {
            resolvedRouter = CHAT_ROUTER_LOCAL;
          }
        } else {
          resolvedRouter = CHAT_ROUTER_LOCAL;
        }
      }
      if (resolvedRouter === CHAT_ROUTER_PLUGIN && !targetNode) {
        res.status(400).json({
          error: "Invalid payload: nodeId must reference an existing platform node",
        });
        return;
      }
      const acceptedTask = await acceptTask(userId, input);
      const acceptedTaskId = acceptedTask.taskId;
      const acceptedSessionId = acceptedTask.sessionId;

      const defaultNode = builtinDefaultNodeRef();
      const isPluginRoute = resolvedRouter === CHAT_ROUTER_PLUGIN;
      const userMessageMetadata = {
        resolvedBotId: input.resolvedBotId,
        resolvedSkillId: input.resolvedSkillId,
        source: isPluginRoute ? "backend.respond.openclaw" : "backend.respond",
        targetNodeId: isPluginRoute ? targetNode?.nodeId : defaultNode.nodeId,
        targetNodeName: isPluginRoute ? targetNode?.displayName : defaultNode.nodeName,
        targetPluginId: isPluginRoute ? targetNode?.pluginId : null,
        pendingAssistantMessageId:
          isPluginRoute ? assistantMessageId : undefined,
        ...(orderedMediaAssets.length > 0
          ? { mediaAttachments: mediaAttachmentsMetadata(orderedMediaAssets) }
          : {}),
      };

      if (resolvedRouter === CHAT_ROUTER_PLUGIN) {
        const persisted = await upsertMessages(userId, [
          {
            messageId: userMessageId,
            taskId: acceptedTaskId,
            channelId,
            sessionId: acceptedSessionId,
            threadId: input.threadId,
            role: "user",
            content: userMessage,
            taskState: "accepted",
            checkpointCursor: null,
            metadata: userMessageMetadata,
            createdAt:
              typeof body.createdAt === "string" ? body.createdAt : null,
          },
        ]);

        try {
          await emitAssistantDispatchPlaceholder({
            userId,
            assistantMessageId,
            acceptedTaskId,
            acceptedSessionId,
            channelId,
            threadId: input.threadId,
            resolvedBotId: input.resolvedBotId,
            resolvedSkillId: input.resolvedSkillId,
            source: "backend.respond.openclaw",
            agentName: targetNode!.displayName?.trim() || targetNode!.nodeId,
          });
        } catch (error) {
          console.error("Chat OpenClaw dispatch placeholder error:", error);
          throw error;
        }

        res.json({
          taskId: acceptedTaskId,
          sessionId: acceptedSessionId,
          assistantMessageId,
          text: "",
          lastSeqId: persisted.lastSeqId,
          state: "accepted",
          mode: "async",
          router: resolvedRouter,
        });
        return;
      }

      const persisted = await upsertMessages(userId, [
        {
          messageId: userMessageId,
          taskId: acceptedTaskId,
          channelId,
          sessionId: acceptedSessionId,
          threadId: input.threadId,
          role: "user",
          content: userMessage,
          taskState: "accepted",
          checkpointCursor: null,
          metadata: userMessageMetadata,
          createdAt: typeof body.createdAt === "string" ? body.createdAt : null,
        },
      ]);

      const scopeInstructions = await resolveScopeInstructions(userId, {
        channelId,
        threadId,
      });
      const systemPrompt =
        typeof body.systemPrompt === "string" && body.systemPrompt.trim()
          ? body.systemPrompt.trim()
          : null;

      void runDefaultRouterRespondAsync({
        userId,
        acceptedTaskId,
        acceptedSessionId,
        assistantMessageId,
        channelId,
        threadId: input.threadId,
        resolvedBotId: input.resolvedBotId,
        resolvedSkillId: input.resolvedSkillId,
        userMessage,
        body,
        maxTokens: parsedMaxTokens.value,
        systemPrompt,
        channelInstructions: scopeInstructions.channelInstructions,
        threadInstructions: scopeInstructions.threadInstructions,
      });

      res.json({
        taskId: acceptedTaskId,
        sessionId: acceptedSessionId,
        assistantMessageId,
        text: "",
        lastSeqId: persisted.lastSeqId,
        state: "accepted",
        mode: "async",
        router: resolvedRouter,
      });
    } catch (error) {
      console.error("Chat respond error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.post("/tasks/accept", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body ?? {};
    const taskId = parseSessionId(body.taskId);
    const idempotencyKey = parseSessionId(body.idempotencyKey);
    const channelId = parseSessionId(body.channelId);
    const sessionId = parseSessionId(body.sessionId);
    if (!taskId || !idempotencyKey || !channelId || !sessionId) {
      res.status(400).json({
        error:
          "Invalid payload: taskId, idempotencyKey, channelId, sessionId are required strings",
      });
      return;
    }

    const input: AcceptTaskInput = {
      taskId,
      idempotencyKey,
      channelId,
      sessionId,
      threadId: parseSessionId(body.threadId),
      resolvedBotId: parseSessionId(body.resolvedBotId),
      resolvedSkillId: parseSessionId(body.resolvedSkillId),
    };

    const accepted = await acceptTask(userId, input);
    res.json(accepted);
  } catch (error) {
    console.error("Accept chat task error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.put("/messages/batch", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const messages = req.body?.messages;
    if (!Array.isArray(messages)) {
      res.status(400).json({ error: "messages must be an array" });
      return;
    }

    const payload: MessageUpsertInput[] = [];
    for (const raw of messages) {
      if (!raw || typeof raw !== "object") continue;
      const msg = raw as Record<string, unknown>;
      const messageId = parseSessionId(msg.messageId);
      const channelId = parseSessionId(msg.channelId);
      const sessionId = parseSessionId(msg.sessionId);
      const role = parseSessionId(msg.role);
      const content = typeof msg.content === "string" ? msg.content : "";
      if (!messageId || !channelId || !sessionId || !role) continue;
      payload.push({
        messageId,
        taskId: parseSessionId(msg.taskId),
        channelId,
        sessionId,
        threadId: parseSessionId(msg.threadId),
        role,
        content,
        taskState: parseSessionId(msg.taskState),
        checkpointCursor: parseSessionId(msg.checkpointCursor),
        metadata:
          msg.metadata &&
          typeof msg.metadata === "object" &&
          !Array.isArray(msg.metadata)
            ? (msg.metadata as Record<string, unknown>)
            : null,
        createdAt: typeof msg.createdAt === "string" ? msg.createdAt : null,
      });
    }

    if (payload.length === 0) {
      res.status(400).json({ error: "No valid messages in payload" });
      return;
    }

    const result = await upsertMessages(userId, payload);
    res.json(result);
  } catch (error) {
    console.error("Batch upsert chat messages error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.get(
  "/sync/:sessionId",
  syncLimiter,
  async (req: AuthRequest, res: Response) => {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ error: "Unauthorized" });
        return;
      }

      const sessionId = parseSessionId(req.params.sessionId);
      if (!sessionId) {
        res.status(400).json({ error: "Invalid sessionId" });
        return;
      }

      const afterSeqRaw = req.query.afterSeq;
      const afterSeq = Math.max(
        0,
        Number.parseInt(
          typeof afterSeqRaw === "string" ? afterSeqRaw : "0",
          10,
        ) || 0,
      );

      const synced = await syncMessages(userId, sessionId, afterSeq);
      res.json(synced);
    } catch (error) {
      console.error("Sync chat messages error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  },
);

router.get(
  "/events/:sessionId",
  eventsLimiter,
  (req: AuthRequest, res: Response) => {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const sessionId = parseSessionId(req.params.sessionId);
    if (!sessionId) {
      res.status(400).json({ error: "Invalid sessionId" });
      return;
    }

    const afterSeqRaw = req.query.afterSeq;
    let afterSeq = Math.max(
      0,
      Number.parseInt(
        typeof afterSeqRaw === "string" ? afterSeqRaw : "0",
        10,
      ) || 0,
    );

    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    res.flushHeaders();

    let disconnected = false;
    let pollTimer: ReturnType<typeof setTimeout> | null = null;
    let heartbeatTimer: ReturnType<typeof setInterval> | null = null;

    const cleanup = () => {
      disconnected = true;
      if (pollTimer !== null) clearTimeout(pollTimer);
      if (heartbeatTimer !== null) clearInterval(heartbeatTimer);
    };

    req.on("close", cleanup);

    heartbeatTimer = setInterval(() => {
      if (!disconnected) res.write(": heartbeat\n\n");
    }, CHAT_EVENTS_HEARTBEAT_INTERVAL_MS);

    const poll = async () => {
      if (disconnected) return;
      try {
        const synced = await syncMessages(userId, sessionId, afterSeq);
        if (
          !disconnected &&
          (synced.messages.length > 0 || synced.lastSeqId > afterSeq)
        ) {
          afterSeq = synced.lastSeqId;
          res.write(`data: ${JSON.stringify(synced)}\n\n`);
        }
      } catch {
        // ignore transient poll errors; client will reconnect on stream close
      }
      if (!disconnected) {
        pollTimer = setTimeout(poll, CHAT_EVENTS_POLL_INTERVAL_MS);
      }
    };

    pollTimer = setTimeout(poll, 0);
  },
);

router.get("/history/:sessionId", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }
    const sessionId = parseSessionId(req.params.sessionId);
    if (!sessionId) {
      res.status(400).json({ error: "Invalid sessionId" });
      return;
    }

    const limitRaw = req.query.limit;
    const limitValue = Array.isArray(limitRaw) ? limitRaw[0] : limitRaw;
    const parsedLimit =
      typeof limitValue === "string"
        ? Number.parseInt(limitValue, 10)
        : Number.NaN;
    const limit = Math.max(
      1,
      Math.min(Number.isNaN(parsedLimit) ? 100 : parsedLimit, 500),
    );

    const synced = await syncMessages(userId, sessionId, 0, { limit });
    const latestCheckpointCursor =
      [...synced.messages].reverse().find((m) => m.checkpointCursor != null)
        ?.checkpointCursor ?? null;
    res.json({
      sessionId,
      messages: synced.messages,
      latestCheckpointCursor,
      lastSeqId: synced.lastSeqId,
    });
  } catch (error) {
    console.error("Get chat history error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.get("/scopes", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const scopes = await listUserScopes(userId);
    res.json({ scopes });
  } catch (error) {
    console.error("List chat scopes error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.get("/scope-settings", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const settings = await listChatScopeSettings(userId);
    const platformNodes = await listPlatformNodes(userId);
    const platformNodeById = new Map(platformNodes.map((node) => [node.nodeId, node]));
    const defaultNode = builtinDefaultNodeRef();
    const enrichedSettings = settings.map((setting) => {
      const platformNode =
        setting.router === CHAT_ROUTER_PLUGIN && setting.nodeId
          ? platformNodeById.get(setting.nodeId) ?? null
          : null;
      return {
        ...setting,
        resolvedTargetNodeId: platformNode?.nodeId ?? defaultNode.nodeId,
        resolvedTargetNodeName: platformNode?.displayName ?? defaultNode.nodeName,
        resolvedTargetPluginId: platformNode?.pluginId ?? null,
      };
    });
    res.json({ settings: enrichedSettings });
  } catch (error) {
    console.error("List chat scope settings error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.get("/channels", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const channels = await listChatChannels(userId);
    res.json({ channels });
  } catch (error) {
    console.error("List chat channels error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.put("/channels", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body ?? {};
    const channelId = parseSessionId(body.channelId);
    const threadId = parseSessionId(body.threadId);
    const displayNameRaw =
      typeof body.displayName === "string" ? body.displayName.trim() : null;

    if (!channelId) {
      res.status(400).json({
        error: "Invalid payload: channelId is required",
      });
      return;
    }

    if (displayNameRaw && displayNameRaw.length > 255) {
      res.status(400).json({
        error: "Invalid payload: displayName must be 255 characters or fewer",
      });
      return;
    }

    if (!displayNameRaw) {
      res.status(400).json({
        error: "Invalid payload: displayName is required",
      });
      return;
    }

    const setting = await upsertChatChannel(userId, {
      channelId,
      threadId,
      displayName: displayNameRaw,
    });
    res.json({ setting });
  } catch (error) {
    console.error("Upsert chat channel error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.post("/channels/archive", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body ?? {};
    const channelId = parseSessionId(body.channelId);
    const threadId = parseSessionId(body.threadId);
    const displayNameRaw =
      typeof body.displayName === "string" ? body.displayName.trim() : "";

    if (!channelId) {
      res.status(400).json({
        error: "Invalid payload: channelId is required",
      });
      return;
    }

    if (displayNameRaw.length > 255) {
      res.status(400).json({
        error: "Invalid payload: displayName must be 255 characters or fewer",
      });
      return;
    }

    const setting = await archiveChatChannel(userId, {
      channelId,
      threadId,
      displayName: displayNameRaw || channelId,
    });
    res.json({ setting });
  } catch (error) {
    console.error("Archive chat channel error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.post("/fork", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body ?? {};
    const parentSessionId = parseSessionId(body.parentSessionId);
    const forkMessageId = parseSessionId(body.forkMessageId);
    const newThreadId = parseSessionId(body.newThreadId);

    if (!parentSessionId || !forkMessageId || !newThreadId) {
      res.status(400).json({
        error: "parentSessionId, forkMessageId, and newThreadId are required",
      });
      return;
    }

    // Derive channelId from parentSessionId (format: session:channelId:threadId)
    const parts = parentSessionId.split(':');
    if (parts.length < 3 || parts[0] !== 'session') {
      res.status(400).json({ error: "Invalid parentSessionId format" });
      return;
    }
    const channelId = parts[1];
    const forkedSessionId = buildChatSessionId(channelId, newThreadId);

    const input: ForkThreadInput = {
      userId,
      forkedSessionId,
      parentSessionId,
      forkMessageId,
    };
    const result = await forkThread(input);

    res.json({
      threadId: newThreadId,
      channelId,
      forkedSessionId: result.forkedSessionId,
      parentSessionId: result.parentSessionId,
      forkWriteSeq: result.forkWriteSeq,
    });
  } catch (error) {
    console.error("Fork thread error:", error);
    if (error instanceof Error && error.message.startsWith("Fork message not found")) {
      res.status(404).json({ error: error.message });
      return;
    }
    res.status(500).json({ error: "Internal server error" });
  }
});

router.put("/scope-settings", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const body = req.body ?? {};
    const scopeType = parseScopeType(body.scopeType);
    const channelId = parseSessionId(body.channelId);
    const threadId = parseSessionId(body.threadId);
    const nodeId = parseSessionId(body.nodeId);
    let instructionsRaw: string | null | undefined;
    if (body.instructions === null || body.instructions === undefined) {
      instructionsRaw = undefined;
    } else if (typeof body.instructions === "string") {
      instructionsRaw = body.instructions;
    } else {
      instructionsRaw = null;
    }
    const routerValue =
      body.router === null || body.router === undefined
        ? null
        : parseChatRouter(body.router);

    if (!scopeType || !channelId) {
      res.status(400).json({
        error: "Invalid payload: scopeType and channelId are required",
      });
      return;
    }

    if (scopeType === "thread" && !threadId) {
      res.status(400).json({
        error:
          "Invalid payload: threadId is required for thread scope settings",
      });
      return;
    }

    if (body.router !== null && body.router !== undefined && !routerValue) {
      res.status(400).json({
        error: 'Invalid payload: router must be "local", "plugin", "default", "openclaw", or null',
      });
      return;
    }

    if (routerValue === CHAT_ROUTER_PLUGIN) {
      if (!nodeId) {
        res.status(400).json({
          error: "Invalid payload: nodeId is required for plugin router",
        });
        return;
      }
      const node = await getPlatformNodeByNodeId(userId, nodeId);
      if (!node) {
        res.status(400).json({
          error: "Invalid payload: nodeId must reference an existing platform node",
        });
        return;
      }
    }

    if (routerValue == null) {
      const deleted = await deleteChatScopeSetting(userId, {
        scopeType,
        channelId,
        threadId,
      });
      res.json({ deleted: deleted.deleted });
      return;
    }

    const setting = await upsertChatScopeSetting(userId, {
      scopeType,
      channelId,
      threadId,
      router: routerValue,
      nodeId: routerValue === CHAT_ROUTER_PLUGIN ? nodeId : null,
      instructions: instructionsRaw,
    });
    res.json({ setting });
  } catch (error) {
    console.error("Upsert chat scope setting error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;
