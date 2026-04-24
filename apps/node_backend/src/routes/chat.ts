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
  CHAT_ROUTER_DEFAULT,
  CHAT_ROUTER_OPENCLAW,
  deleteChatScopeSetting,
  listChatScopeSettings,
  resolveChatRouter,
  type ChatRouter,
  type ChatScopeType,
  upsertChatScopeSetting,
} from "../services/chatRouterService.js";
import {
  deleteChatChannelName,
  listChatChannelNames,
  upsertChatChannelName,
} from "../services/chatChannelNameService.js";
import { streamWithUserConfig } from "../llm/llm_service.js";
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

function dispatchPlaceholderMetadata(params: {
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
  source: string;
  model?: string | null;
  agentName?: string | null;
}) {
  return {
    resolvedBotId: params.resolvedBotId,
    resolvedSkillId: params.resolvedSkillId,
    source: params.source,
    model: params.model ?? undefined,
    agentName: params.agentName ?? undefined,
    dispatchPlaceholder: true,
  };
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
  if (value === CHAT_ROUTER_DEFAULT || value === CHAT_ROUTER_OPENCLAW) {
    return value;
  }
  return null;
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

async function runDefaultRouterRespondAsync(params: {
  userId: string;
  acceptedTaskId: string;
  acceptedSessionId: string;
  assistantMessageId: string;
  channelId: string;
  threadId: string | null;
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
  body: Record<string, unknown>;
  maxTokens: number;
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
    body,
    maxTokens,
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

    const modelMessages = await listSessionMessagesForModel(userId, acceptedSessionId, {
      limit: 40,
      maxChars: 10000,
    });

    const { textStream, provider, modelId } = await streamWithUserConfig(
      userId,
      {
        model: typeof body.model === "string" ? body.model : undefined,
        configId: typeof body.configId === "string" ? body.configId : undefined,
        messages: modelMessages,
        maxTokens,
      },
      parseProvider(body.provider),
    );

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
      const resolvedRouter = await resolveChatRouter(userId, {
        channelId,
        threadId,
      });
      const acceptedTask = await acceptTask(userId, input);
      const acceptedTaskId = acceptedTask.taskId;
      const acceptedSessionId = acceptedTask.sessionId;

      const userMessageMetadata = {
        resolvedBotId: input.resolvedBotId,
        resolvedSkillId: input.resolvedSkillId,
        source:
          resolvedRouter === CHAT_ROUTER_OPENCLAW
            ? "backend.respond.openclaw"
            : "backend.respond",
        pendingAssistantMessageId:
          resolvedRouter === CHAT_ROUTER_OPENCLAW
            ? assistantMessageId
            : undefined,
      };

      if (resolvedRouter === CHAT_ROUTER_OPENCLAW) {
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
            agentName: "OpenClaw",
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

      void runDefaultRouterRespondAsync({
        userId,
        acceptedTaskId,
        acceptedSessionId,
        assistantMessageId,
        channelId,
        threadId: input.threadId,
        resolvedBotId: input.resolvedBotId,
        resolvedSkillId: input.resolvedSkillId,
        body,
        maxTokens: parsedMaxTokens.value,
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
    res.json({ settings });
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
      const deleted = await deleteChatChannelName(userId, channelId);
      res.json({ deleted: deleted.deleted });
      return;
    }

    const setting = await upsertChatChannelName(userId, {
      channelId,
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
        error: 'Invalid payload: router must be "default", "openclaw", or null',
      });
      return;
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
    });
    res.json({ setting });
  } catch (error) {
    console.error("Upsert chat scope setting error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;
