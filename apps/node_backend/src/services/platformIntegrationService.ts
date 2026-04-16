import pool from '../db/index.js';
import { upsertMessages } from './chatAsyncTransportService.js';

type ChatMessageEventRow = {
  write_seq: number;
  message_id: string;
  user_id: string;
  channel_id: string;
  session_id: string;
  thread_id: string | null;
  role: string;
  content: string;
  created_at: string;
};

type ExistingMessageRow = {
  message_id: string;
  user_id: string;
  channel_id: string;
  session_id: string;
  thread_id: string | null;
  role: string;
  content: string;
  metadata: unknown;
  created_at: string;
  updated_at: string;
};

export interface PlatformEvent {
  eventId: string;
  eventType: 'message.created';
  workspaceId: string;
  conversationId: string;
  rawId: string;
  occurredAt: string;
  payload: {
    messageId: string;
    sender: {
      userId: string;
      displayName: string;
    };
    text: string;
    attachments: unknown[];
  };
}

function cursorToSeq(cursor?: string): number {
  if (!cursor) return 0;
  const m = /^cur_(\d+)$/.exec(cursor.trim());
  if (!m) {
    throw new Error('INVALID_CURSOR');
  }
  return Number.parseInt(m[1], 10);
}

function seqToCursor(seq: number): string {
  return `cur_${Math.max(0, seq)}`;
}

function toRawId(channelId: string, threadId: string | null): string {
  if (threadId && threadId.trim().length > 0) {
    return `channel:${channelId}/thread:${threadId}`;
  }
  return `channel:${channelId}`;
}

function displayNameFromRole(role: string): string {
  switch (role) {
    case 'assistant':
      return 'assistant';
    case 'system':
      return 'system';
    default:
      return 'user';
  }
}

export async function listPlatformEvents(params: {
  cursor?: string;
  limit?: number;
  workspaceId?: string;
  userId?: string;
}): Promise<{ nextCursor: string; events: PlatformEvent[] }> {
  const limit = Math.min(200, Math.max(1, params.limit ?? 50));
  const afterSeq = cursorToSeq(params.cursor);
  const workspaceId = params.workspaceId ?? process.env.BRICKS_PLATFORM_WORKSPACE_ID ?? 'ws_local';

  const baseSelect = `SELECT write_seq, message_id, user_id, channel_id, session_id, thread_id, role, content, created_at
       FROM chat_messages`;
  const queryParams: unknown[] = [afterSeq, limit];
  const userFilter = params.userId ? ` AND user_id = $${queryParams.push(params.userId)}` : '';
  const result = await pool.query<ChatMessageEventRow>(
    `${baseSelect}
      WHERE write_seq > $1${userFilter}
      ORDER BY write_seq ASC
      LIMIT $2`,
    queryParams,
  );

  const events = result.rows.map((row) => ({
    eventId: `evt_msg_${row.message_id}_${row.write_seq}`,
    eventType: 'message.created' as const,
    workspaceId,
    conversationId: row.session_id,
    rawId: toRawId(row.channel_id, row.thread_id),
    occurredAt: row.created_at,
    payload: {
      messageId: row.message_id,
      sender: {
        userId: row.user_id,
        displayName: displayNameFromRole(row.role),
      },
      text: row.content,
      attachments: [],
    },
  }));

  const nextSeq = result.rows.length > 0 ? result.rows[result.rows.length - 1].write_seq : afterSeq;
  return {
    nextCursor: seqToCursor(nextSeq),
    events,
  };
}

export async function ackPlatformEvents(params: {
  pluginId: string;
  cursor: string;
  ackedEventIds: string[];
}): Promise<{ ok: true }> {
  // Validate inputs even though ACK persistence is intentionally deferred in the MVP.
  // This keeps the endpoint idempotent while surfacing client-side protocol bugs.
  cursorToSeq(params.cursor);
  if (!Array.isArray(params.ackedEventIds)) {
    throw new Error('INVALID_ACKED_EVENT_IDS');
  }
  for (const eventId of params.ackedEventIds) {
    if (typeof eventId !== 'string' || eventId.trim().length === 0) {
      throw new Error('INVALID_ACKED_EVENT_IDS');
    }
  }
  return { ok: true };
}

function generateMessageId(clientToken?: string): string {
  if (clientToken && clientToken.trim().length > 0) {
    return clientToken.trim().slice(0, 255);
  }
  return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export async function createPlatformMessage(input: {
  userId: string;
  conversationId: string;
  channelId: string;
  threadId?: string | null;
  role: string;
  text: string;
  clientToken?: string;
  metadata?: Record<string, unknown>;
}): Promise<{ messageId: string; conversationId: string; revision: number }> {
  const messageId = generateMessageId(input.clientToken);

  await upsertMessages(input.userId, [
    {
      messageId,
      taskId: null,
      channelId: input.channelId,
      sessionId: input.conversationId,
      threadId: input.threadId ?? null,
      role: input.role,
      content: input.text,
      taskState: null,
      checkpointCursor: null,
      metadata: input.metadata ?? { source: 'platform.messages.create' },
      createdAt: null,
    },
  ]);

  return {
    messageId,
    conversationId: input.conversationId,
    revision: 1,
  };
}

function parseMetadata(raw: unknown): Record<string, unknown> | null {
  if (!raw) return null;
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return null;
    }
  }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return null;
}

export async function patchPlatformMessage(input: {
  userId: string;
  messageId: string;
  text?: string;
  metadata?: Record<string, unknown>;
}): Promise<{ messageId: string; updated: true } | null> {
  const existing = await pool.query<ExistingMessageRow>(
    `SELECT message_id, user_id, channel_id, session_id, thread_id, role, content, metadata, created_at, updated_at
       FROM chat_messages
      WHERE user_id = $1 AND message_id = $2
      LIMIT 1`,
    [input.userId, input.messageId],
  );
  const row = existing.rows[0];
  if (!row) return null;

  const mergedMetadata = {
    ...(parseMetadata(row.metadata) ?? {}),
    ...(input.metadata ?? {}),
    source: 'platform.messages.patch',
  };

  await upsertMessages(input.userId, [
    {
      messageId: row.message_id,
      taskId: null,
      channelId: row.channel_id,
      sessionId: row.session_id,
      threadId: row.thread_id,
      role: row.role,
      content: input.text ?? row.content,
      taskState: null,
      checkpointCursor: null,
      metadata: mergedMetadata,
      createdAt: row.created_at,
    },
  ]);

  return {
    messageId: row.message_id,
    updated: true,
  };
}

/** Returns a SQL filter clause and appends the userId to queryParams when provided. */
function appendUserIdFilter(userId: string | undefined, queryParams: unknown[]): string {
  if (!userId) return '';
  return ` AND user_id = $${queryParams.push(userId)}`;
}

export async function resolveConversation(params: {
  conversationId?: string;
  rawId?: string;
  userId?: string;
}): Promise<
  | {
      conversationId: string;
      rawId: string;
      channelId: string;
      threadId: string | null;
    }
  | null
> {
  if (params.conversationId && params.conversationId.trim().length > 0) {
    const queryParams: unknown[] = [params.conversationId.trim()];
    const userFilter = appendUserIdFilter(params.userId, queryParams);

    const byConversation = await pool.query<{
      session_id: string;
      channel_id: string;
      thread_id: string | null;
    }>(
      `SELECT session_id, channel_id, thread_id
         FROM chat_messages
        WHERE session_id = $1${userFilter}
        ORDER BY write_seq DESC
        LIMIT 1`,
      queryParams,
    );

    const row = byConversation.rows[0];
    if (!row) return null;
    return {
      conversationId: row.session_id,
      channelId: row.channel_id,
      threadId: row.thread_id,
      rawId: toRawId(row.channel_id, row.thread_id),
    };
  }

  if (!params.rawId || params.rawId.trim().length === 0) {
    return null;
  }

  const raw = params.rawId.trim();
  const parsed = /^channel:([^/]+)(?:\/thread:(.+))?$/.exec(raw);
  if (!parsed) return null;

  const channelId = parsed[1];
  const threadId = parsed[2] ?? null;

  const rawQueryParams: unknown[] = [channelId, threadId];
  const rawUserFilter = appendUserIdFilter(params.userId, rawQueryParams);

  const byRawId = await pool.query<{
    session_id: string;
    channel_id: string;
    thread_id: string | null;
  }>(
    `SELECT session_id, channel_id, thread_id
       FROM chat_messages
      WHERE channel_id = $1
        AND (($2 IS NULL AND thread_id IS NULL) OR thread_id = $2)${rawUserFilter}
      ORDER BY write_seq DESC
      LIMIT 1`,
    rawQueryParams,
  );

  const row = byRawId.rows[0];
  if (!row) return null;

  return {
    conversationId: row.session_id,
    channelId: row.channel_id,
    threadId: row.thread_id,
    rawId: toRawId(row.channel_id, row.thread_id),
  };
}
