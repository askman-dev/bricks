import express, { type Request, type Response } from 'express';
import {
  authenticatePlatformApiKey,
  requirePlatformScope,
  type PlatformAuthRequest,
} from '../middleware/platformAuth.js';
import {
  ackPlatformEvents,
  createPlatformMessage,
  listPlatformEvents,
  patchPlatformMessage,
  resolveConversation,
} from '../services/platformIntegrationService.js';

const router = express.Router();
router.use(authenticatePlatformApiKey);

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

router.get('/events', requirePlatformScope('events:read'), async (req: Request, res: Response) => {
  try {
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

    const response = await listPlatformEvents({ cursor: cursor ?? undefined, limit });
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

      await ackPlatformEvents({
        pluginId: req.platformPluginId ?? 'unknown',
        ackedEventIds,
        cursor,
      });
      res.status(200).json({ ok: true });
    } catch (error) {
      console.error('platform ack error:', error);
      sendError(res, 500, 'INTERNAL_ERROR', 'internal server error', true);
    }
  },
);

router.post(
  '/messages',
  requirePlatformScope('messages:write'),
  async (req: PlatformAuthRequest, res: Response) => {
  try {
    const userId = readTrimmedString(req.body?.userId) ?? req.platformUserId ?? null;
    const conversationId = readTrimmedString(req.body?.conversationId);
    const channelId = readTrimmedString(req.body?.channelId);
    const text = readTrimmedString(req.body?.text);
    const role = readTrimmedString(req.body?.role) ?? 'assistant';

    if (!userId || !conversationId || !channelId || !text) {
      sendError(
        res,
        400,
        'INVALID_PAYLOAD',
        'userId, conversationId, channelId, text are required',
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
  requirePlatformScope('messages:write'),
  async (req: PlatformAuthRequest, res: Response) => {
    try {
      const messageId = readTrimmedString(req.params.messageId);
      const userId = readTrimmedString(req.body?.userId) ?? req.platformUserId ?? null;
      if (!messageId || !userId) {
        sendError(res, 400, 'INVALID_PAYLOAD', 'messageId param and userId body are required');
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
  requirePlatformScope('conversations:read'),
  async (req: Request, res: Response) => {
    try {
      const conversationId = readTrimmedString(req.query.conversationId);
      const rawId = readTrimmedString(req.query.rawId);
      if (!conversationId && !rawId) {
        sendError(res, 400, 'INVALID_QUERY', 'conversationId or rawId is required');
        return;
      }

      const resolved = await resolveConversation({ conversationId: conversationId ?? undefined, rawId: rawId ?? undefined });
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

export default router;
