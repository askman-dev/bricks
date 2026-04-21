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
import { generateWithUserConfig } from "../llm/llm_service.js";
import type { LlmProvider } from "../llm/types.js";

const router = express.Router();
router.use(authenticate);

const CHAT_SYNC_WINDOW_MS = 60 * 1000;
const CHAT_SYNC_MAX_REQUESTS_PER_WINDOW = 120;
const CHAT_RESPOND_WINDOW_MS = 60 * 1000;
const CHAT_RESPOND_MAX_REQUESTS_PER_WINDOW = 120;
// Keep long-poll waits comfortably below common serverless request limits so
// the application returns the response before the platform times out.
const CHAT_SYNC_LONG_POLL_MAX_WAIT_MS = 9000;
const CHAT_SYNC_LONG_POLL_INTERVAL_MS = 500;

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

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

      await upsertMessages(userId, [
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

      const modelMessages = await listSessionMessagesForModel(
        userId,
        acceptedSessionId,
        {
          limit: 40,
          maxChars: 10000,
        },
      );

      const response = await generateWithUserConfig(
        userId,
        {
          model: typeof body.model === "string" ? body.model : undefined,
          configId:
            typeof body.configId === "string" ? body.configId : undefined,
          messages: modelMessages,
        },
        parseProvider(body.provider),
      );

      const persisted = await upsertMessages(userId, [
        {
          messageId: assistantMessageId,
          taskId: acceptedTaskId,
          channelId,
          sessionId: acceptedSessionId,
          threadId: input.threadId,
          role: "assistant",
          content: response.text,
          taskState: "completed",
          checkpointCursor: null,
          metadata: {
            resolvedBotId: input.resolvedBotId,
            resolvedSkillId: input.resolvedSkillId,
            provider: response.provider,
            model: response.model,
            source: "backend.respond",
          },
          createdAt: null,
        },
      ]);

      res.json({
        taskId: acceptedTaskId,
        sessionId: acceptedSessionId,
        assistantMessageId,
        text: response.text,
        provider: response.provider,
        model: response.model,
        lastSeqId: persisted.lastSeqId,
        state: "completed",
        mode: "sync",
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

      const requestedWaitMs = parseNonNegativeInt(req.query.waitMs);
      const waitMs = Math.min(
        requestedWaitMs ?? 0,
        CHAT_SYNC_LONG_POLL_MAX_WAIT_MS,
      );

      let clientDisconnected = false;
      const onClose = () => {
        clientDisconnected = true;
      };
      req.on("close", onClose);

      try {
        const startedAt = Date.now();
        let synced = await syncMessages(userId, sessionId, afterSeq);
        while (
          !clientDisconnected &&
          waitMs > 0 &&
          synced.messages.length === 0 &&
          synced.lastSeqId <= afterSeq &&
          Date.now() - startedAt < waitMs
        ) {
          const elapsed = Date.now() - startedAt;
          const remaining = waitMs - elapsed;
          if (remaining <= 0) break;
          await sleep(Math.min(CHAT_SYNC_LONG_POLL_INTERVAL_MS, remaining));
          if (clientDisconnected) break;
          synced = await syncMessages(userId, sessionId, afterSeq);
        }

        if (clientDisconnected) return;
        res.json(synced);
      } finally {
        req.off("close", onClose);
      }
    } catch (error) {
      console.error("Sync chat messages error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
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
