import express, { type Request, type Response } from 'express';
import rateLimit from 'express-rate-limit';
import {
  authenticatePlatformApiKey,
  requirePlatformScope,
  type PlatformAuthRequest,
} from '../middleware/platformAuth.js';
import {
  MAX_PLATFORM_ACK_BATCH_SIZE,
  ackPlatformEvents,
  createPlatformMessage,
  listPlatformEvents,
  patchPlatformMessage,
  resolveConversation,
} from '../services/platformIntegrationService.js';

const DEFAULT_PLATFORM_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const DEFAULT_PLATFORM_READ_LIMIT_MAX = 300;
const DEFAULT_PLATFORM_WRITE_LIMIT_MAX = 600;

interface PlatformRateLimitOptions {
  windowMs?: number;
  readMax?: number;
  writeMax?: number;
}

function requestId(): string {
  return `req_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function sendError(
  res: Response,
  status: number,
  code: string,
  message: string,
  retryable = false,
): void {
  res.status(status).json({
    error: { code, message, retryable },
    requestId: requestId(),
  });
}

function readTrimmedString(input: unknown): string | null {
  if (typeof input !== 'string') return null;
  const trimmed = input.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Resolves the effective userId for a platform request.
 * When a JWT token is present, its userId is canonical and body userId must match or be absent.
 * In static API key mode, body userId is used directly.
 * Returns the resolved userId or null if unavailable, and an error descriptor if mismatch is detected.
 */
function resolveRequestUserId(
  platformUserId: string | undefined,
  bodyUserId: string | null,
): { userId: string | null; mismatch: boolean } {
  if (platformUserId) {
    if (bodyUserId && bodyUserId !== platformUserId) {
      return { userId: null, mismatch: true };
    }
    return { userId: platformUserId, mismatch: false };
  }
  return { userId: bodyUserId, mismatch: false };
}

function platformLimiterKey(req: PlatformAuthRequest): string {
  const pluginId = req.platformPluginId?.trim() || 'unknown-plugin';
  const scopedIdentity =
    req.platformUserId?.trim()
    || req.ip
    || req.socket.remoteAddress
    || 'unknown-client';
  return `${pluginId}:${scopedIdentity}`;
}

function resolveRetryAfterSeconds(
  req: Request,
  fallbackWindowMs: number,
): number {
  const resetTime = (req as Request & { rateLimit?: { resetTime?: Date } }).rateLimit?.resetTime;
  if (resetTime instanceof Date) {
    const remainingMs = resetTime.getTime() - Date.now();
    return Math.max(1, Math.ceil(remainingMs / 1000));
  }
  return Math.max(1, Math.ceil(fallbackWindowMs / 1000));
}

function createPlatformLimiter(params: {
  windowMs: number;
  max: number;
  message: string;
}): ReturnType<typeof rateLimit> {
  return rateLimit({
    windowMs: params.windowMs,
    max: params.max,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => platformLimiterKey(req as PlatformAuthRequest),
    handler: (req, res) => {
      res.setHeader('Retry-After', String(resolveRetryAfterSeconds(req, params.windowMs)));
      sendError(res, 429, 'RATE_LIMITED', params.message, true);
    },
  });
}

export function createPlatformRouter(options: {
  rateLimit?: PlatformRateLimitOptions;
} = {}): express.Router {
  const router = express.Router();
  router.use(authenticatePlatformApiKey);

  const windowMs = options.rateLimit?.windowMs ?? DEFAULT_PLATFORM_RATE_LIMIT_WINDOW_MS;
  const readLimiter = createPlatformLimiter({
    windowMs,
    max: options.rateLimit?.readMax ?? DEFAULT_PLATFORM_READ_LIMIT_MAX,
    message: 'Too many platform read requests, please try again later.',
  });
  const writeLimiter = createPlatformLimiter({
    windowMs,
    max: options.rateLimit?.writeMax ?? DEFAULT_PLATFORM_WRITE_LIMIT_MAX,
    message: 'Too many platform write requests, please try again later.',
  });

  router.get('/events', readLimiter, requirePlatformScope('events:read'), async (req: Request, res: Response) => {
    try {
      const platformReq = req as PlatformAuthRequest;
      const cursor = readTrimmedString(req.query.cursor);
      const limitRaw = req.query.limit;
      const limit =
        typeof limitRaw === 'string' && limitRaw.trim().length > 0
          ? Number.parseInt(limitRaw, 10)
          : undefined;

      if (limit !== undefined && (!Number.isFinite(limit) || limit <= 0)) {
        sendError(res, 400, 'INVALID_LIMIT', 'limit must be a positive integer');
        return;
      }

      const response = await listPlatformEvents({
        cursor: cursor ?? undefined,
        limit,
        userId: platformReq.platformUserId,
      });
      res.status(200).json(response);
    } catch (error) {
      if (error instanceof Error && error.message === 'INVALID_CURSOR') {
        sendError(res, 400, 'INVALID_CURSOR', 'cursor is malformed');
        return;
      }
      console.error('platform events error:', error);
      sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
    }
  });

  router.post(
    '/events/ack',
    writeLimiter,
    requirePlatformScope('events:ack'),
    async (req: PlatformAuthRequest, res: Response) => {
      try {
        if (req.body && typeof req.body === 'object' && 'pluginId' in req.body) {
          sendError(res, 400, 'INVALID_PAYLOAD', 'pluginId body field is forbidden');
          return;
        }

        const ackedEventIds = Array.isArray(req.body?.ackedEventIds)
          ? req.body.ackedEventIds.filter((v: unknown) => typeof v === 'string' && v.trim().length > 0)
          : null;
        const cursor = readTrimmedString(req.body?.cursor);

        if (!ackedEventIds || !cursor) {
          sendError(res, 400, 'INVALID_PAYLOAD', 'ackedEventIds and cursor are required');
          return;
        }

        if (ackedEventIds.length > MAX_PLATFORM_ACK_BATCH_SIZE) {
          sendError(
            res,
            400,
            'INVALID_PAYLOAD',
            `ackedEventIds must contain no more than ${MAX_PLATFORM_ACK_BATCH_SIZE} items`,
          );
          return;
        }

        await ackPlatformEvents({
          pluginId: req.platformPluginId ?? 'unknown',
          userId: req.platformUserId,
          ackedEventIds,
          cursor,
        });
        res.status(200).json({ ok: true });
      } catch (error) {
        if (error instanceof Error && error.message === 'INVALID_CURSOR') {
          sendError(res, 400, 'INVALID_CURSOR', 'cursor is malformed');
          return;
        }
        if (error instanceof Error && error.message === 'TOO_MANY_ACKED_EVENT_IDS') {
          sendError(
            res,
            400,
            'INVALID_PAYLOAD',
            `ackedEventIds must contain no more than ${MAX_PLATFORM_ACK_BATCH_SIZE} items`,
          );
          return;
        }
        if (error instanceof Error && error.message === 'INVALID_ACKED_EVENT_IDS') {
          sendError(res, 400, 'INVALID_PAYLOAD', 'one or more ackedEventIds are malformed');
          return;
        }
        console.error('platform ack error:', error);
        sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
      }
    },
  );

  router.post(
    '/messages',
    writeLimiter,
    requirePlatformScope('messages:write'),
    async (req: PlatformAuthRequest, res: Response) => {
      try {
        const { userId, mismatch } = resolveRequestUserId(
          req.platformUserId,
          readTrimmedString(req.body?.userId),
        );
        if (mismatch) {
          sendError(res, 403, 'FORBIDDEN', 'userId in body does not match token');
          return;
        }

        const conversationId = readTrimmedString(req.body?.conversationId);
        const channelId = readTrimmedString(req.body?.channelId);
        // Support both `text` and `content` field names per OpenClaw contract
        const text = readTrimmedString(req.body?.text) ?? readTrimmedString(req.body?.content);
        // Support both `role` and `author` field names per OpenClaw contract
        const role = readTrimmedString(req.body?.role) ?? readTrimmedString(req.body?.author) ?? 'assistant';

        if (!userId || !conversationId || !channelId || !text) {
          sendError(
            res,
            400,
            'INVALID_PAYLOAD',
            'userId, conversationId, channelId, and text or content are required',
          );
          return;
        }

        const result = await createPlatformMessage({
          userId,
          conversationId,
          channelId,
          threadId: readTrimmedString(req.body?.threadId),
          text,
          role,
          clientToken: readTrimmedString(req.body?.clientToken) ?? undefined,
          metadata:
            req.body?.metadata && typeof req.body.metadata === 'object' && !Array.isArray(req.body.metadata)
              ? (req.body.metadata as Record<string, unknown>)
              : undefined,
        });

        res.status(200).json(result);
      } catch (error) {
        console.error('platform create message error:', error);
        sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
      }
    },
  );

  router.patch(
    '/messages/:messageId',
    writeLimiter,
    requirePlatformScope('messages:write'),
    async (req: PlatformAuthRequest, res: Response) => {
      try {
        const messageId = readTrimmedString(req.params.messageId);
        const { userId, mismatch } = resolveRequestUserId(
          req.platformUserId,
          readTrimmedString(req.body?.userId),
        );
        if (mismatch) {
          sendError(res, 403, 'FORBIDDEN', 'userId in body does not match token');
          return;
        }

        if (!messageId || !userId) {
          sendError(res, 400, 'INVALID_PAYLOAD', 'messageId param and userId are required');
          return;
        }

        const text = readTrimmedString(req.body?.text);
        const metadata =
          req.body?.metadata && typeof req.body.metadata === 'object' && !Array.isArray(req.body.metadata)
            ? (req.body.metadata as Record<string, unknown>)
            : undefined;

        if (!text && !metadata) {
          sendError(res, 400, 'INVALID_PAYLOAD', 'at least one of text or metadata is required');
          return;
        }

        const result = await patchPlatformMessage({ userId, messageId, text: text ?? undefined, metadata });
        if (!result) {
          sendError(res, 404, 'MESSAGE_NOT_FOUND', 'message not found');
          return;
        }

        res.status(200).json(result);
      } catch (error) {
        console.error('platform patch message error:', error);
        sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
      }
    },
  );

  router.get(
    '/conversations/resolve',
    readLimiter,
    requirePlatformScope('conversations:read'),
    async (req: Request, res: Response) => {
      try {
        const platformReq = req as PlatformAuthRequest;
        const conversationId = readTrimmedString(req.query.conversationId);
        const rawId = readTrimmedString(req.query.rawId);
        if (!conversationId && !rawId) {
          sendError(res, 400, 'INVALID_QUERY', 'conversationId or rawId is required');
          return;
        }

        const resolved = await resolveConversation({
          conversationId: conversationId ?? undefined,
          rawId: rawId ?? undefined,
          userId: platformReq.platformUserId,
        });
        if (!resolved) {
          sendError(res, 404, 'CONVERSATION_NOT_FOUND', 'conversation not found');
          return;
        }

        res.status(200).json(resolved);
      } catch (error) {
        console.error('platform resolve conversation error:', error);
        sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
      }
    },
  );

  return router;
}

const router = createPlatformRouter();

export default router;
