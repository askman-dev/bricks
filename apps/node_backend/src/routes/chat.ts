import express, { Response } from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  acceptTask,
  syncMessages,
  upsertMessages,
  type AcceptTaskInput,
  type MessageUpsertInput,
} from '../services/chatAsyncTransportService.js';

const router = express.Router();
router.use(authenticate);

function parseSessionId(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > 255) return null;
  return trimmed;
}

router.post('/tasks/accept', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
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
          'Invalid payload: taskId, idempotencyKey, channelId, sessionId are required strings',
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
    console.error('Accept chat task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/messages/batch', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const messages = req.body?.messages;
    if (!Array.isArray(messages)) {
      res.status(400).json({ error: 'messages must be an array' });
      return;
    }

    const payload: MessageUpsertInput[] = [];
    for (const raw of messages) {
      if (!raw || typeof raw !== 'object') continue;
      const msg = raw as Record<string, unknown>;
      const messageId = parseSessionId(msg.messageId);
      const channelId = parseSessionId(msg.channelId);
      const sessionId = parseSessionId(msg.sessionId);
      const role = parseSessionId(msg.role);
      const content = typeof msg.content === 'string' ? msg.content : '';
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
          msg.metadata && typeof msg.metadata === 'object' && !Array.isArray(msg.metadata)
            ? (msg.metadata as Record<string, unknown>)
            : null,
        createdAt: typeof msg.createdAt === 'string' ? msg.createdAt : null,
      });
    }

    if (payload.length === 0) {
      res.status(400).json({ error: 'No valid messages in payload' });
      return;
    }

    const result = await upsertMessages(userId, payload);
    res.json(result);
  } catch (error) {
    console.error('Batch upsert chat messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/sync/:sessionId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const sessionId = parseSessionId(req.params.sessionId);
    if (!sessionId) {
      res.status(400).json({ error: 'Invalid sessionId' });
      return;
    }

    const afterSeqRaw = req.query.afterSeq;
    const afterSeq = Math.max(
      0,
      Number.parseInt(typeof afterSeqRaw === 'string' ? afterSeqRaw : '0', 10) || 0,
    );

    const synced = await syncMessages(userId, sessionId, afterSeq);
    res.json(synced);
  } catch (error) {
    console.error('Sync chat messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/history/:sessionId', async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const sessionId = parseSessionId(req.params.sessionId);
    if (!sessionId) {
      res.status(400).json({ error: 'Invalid sessionId' });
      return;
    }

    const synced = await syncMessages(userId, sessionId, 0);
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
    console.error('Get chat history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
