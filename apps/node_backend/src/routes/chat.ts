import express, { Response } from "express";
import rateLimit from "express-rate-limit";
import { authenticate, AuthRequest } from "../middleware/auth.js";
import {
  acceptTask,
  listUserScopes,
  listSessionMessagesForModel,
  syncMessages,
  upsertMessages,
  type AcceptTaskInput,
  type MessageUpsertInput,
} from "../services/chatAsyncTransportService.js";
import {
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
  deleteChatChannelName,
  listChatChannelNames,
  upsertChatChannelName,
} from "../services/chatChannelNameService.js";
import {
  getPlatformNodeByNodeId,
  listPlatformNodes,
} from "../services/platformNodeService.js";
import { streamWithAgentToolsAndUserConfig } from "../llm/llm_service.js";
import {
  buildAgentTools,
} from "../services/localAgentLoopService.js";
import type { LlmProvider } from "../llm/types.js";
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
const DEFAULT_INTERNAL_LOOP_MAX_STEPS = 4;
const DEFAULT_INTERNAL_LOOP_MAX_TOOL_CALLS = 4;
const DEFAULT_INTERNAL_LOOP_TIMEOUT_MS = 15000;

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
      max: 20,
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
    let toolStepIndex = 0;

    // Always use the agent-loop path so the model is aware of (and can invoke)
    // internal tools regardless of whether the user typed a slash command or
    // plain natural language.  The managedStream generator yields text deltas
    // eagerly for tool-free steps, so streaming UX is equivalent to the direct
    // streamWithUserConfig path for ordinary chat messages.
    const agentTools = buildAgentTools(userId);
    ({ textStream, provider, modelId } = await streamWithAgentToolsAndUserConfig(
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
      ));

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

    await upsertMessages(userId, [
      {
        messageId: assistantMessageId,
        taskId: acceptedTaskId,
        channelId,
        sessionId: acceptedSessionId,
        threadId,
        role: "assistant",
        content: assistantContent,
        taskState: "completed",
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
      },
    ]);
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
      const parsedMaxTokens = parseMaxTokens(body.maxTokens);

      if (
        !taskId ||
        !idempotencyKey ||
        !channelId ||
        !sessionId ||
        !userMessageId ||
        !assistantMessageId ||
        !userMessage
      ) {
        res.status(400).json({
          error:
            "Invalid payload: taskId, idempotencyKey, channelId, sessionId, userMessageId, assistantMessageId, userMessage are required",
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

router.get("/channel-names", async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const channelNames = await listChatChannelNames(userId);
    res.json({ channelNames });
  } catch (error) {
    console.error("List chat channel names error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

router.put("/channel-names", async (req: AuthRequest, res: Response) => {
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
      const deleted = await deleteChatChannelName(userId, channelId, threadId);
      res.json({ deleted: deleted.deleted });
      return;
    }

    const setting = await upsertChatChannelName(userId, {
      channelId,
      threadId,
      displayName: displayNameRaw,
    });
    res.json({ setting });
  } catch (error) {
    console.error("Upsert chat channel name error:", error);
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
