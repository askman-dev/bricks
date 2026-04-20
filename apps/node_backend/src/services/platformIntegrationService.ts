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
  metadata: unknown;
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
       metadata?: Record<string, unknown>;
      };
}

export const MAX_PLATFORM_EVENTS_LIMIT = 200;
export const MAX_PLATFORM_ACK_BATCH_SIZE = MAX_PLATFORM_EVENTS_LIMIT;
const DEFAULT_PLATFORM_EVENTS_LIMIT = 50;
const TURSO_ACK_UPDATE_CHUNK_SIZE = 50;

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
  const limit = Math.min(MAX_PLATFORM_EVENTS_LIMIT, Math.max(1, params.limit ?? DEFAULT_PLATFORM_EVENTS_LIMIT));
  const afterSeq = cursorToSeq(params.cursor);
  const workspaceId = params.workspaceId ?? process.env.BRICKS_PLATFORM_WORKSPACE_ID ?? 'ws_local';

  const baseSelect = `SELECT
         msg.write_seq,
         msg.message_id,
         msg.user_id,
         msg.channel_id,
         msg.session_id,
         msg.thread_id,
         msg.role,
         msg.content,
         msg.created_at,
         msg.metadata
       FROM chat_messages msg`;
  const queryParams: unknown[] = [afterSeq, limit];
  const userFilter = appendUserIdFilter(params.userId, queryParams);
  const result = await pool.query<ChatMessageEventRow>(
    `${baseSelect}
      WHERE msg.write_seq > $1${userFilter}
        AND msg.role = 'user'
        AND msg.task_state IN ('accepted', 'dispatched')
        AND CAST(msg.metadata AS TEXT) LIKE '%pendingAssistantMessageId%'
      ORDER BY msg.write_seq ASC
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
      metadata: parseMetadata(row.metadata) ?? undefined,
    },
  }));

  const nextSeq =
    result.rows.length > 0
      ? result.rows[result.rows.length - 1].write_seq
      : afterSeq;
  return {
    nextCursor: seqToCursor(nextSeq),
    events,
  };
}

export async function ackPlatformEvents(params: {
  pluginId: string;
  userId?: string;
  cursor: string;
  ackedEventIds: string[];
}): Promise<{ ok: true }> {
  cursorToSeq(params.cursor);
  if (!Array.isArray(params.ackedEventIds)) {
    throw new Error('INVALID_ACKED_EVENT_IDS');
  }

  const parsedAckedMessages = params.ackedEventIds.map(parseAckedMessageEventId);
  if (parsedAckedMessages.some((item) => item === null)) {
    throw new Error('INVALID_ACKED_EVENT_IDS');
  }

  // Deduplicate to prevent redundant DB updates for duplicate event IDs in the payload.
  const ackedMessages = Array.from(
    new Map(
      parsedAckedMessages
        .filter((item): item is { messageId: string; writeSeq: number } => item !== null)
        .map((item) => [`${item.messageId}:${item.writeSeq}`, item] as const),
    ).values(),
  );

  if (ackedMessages.length === 0) {
    return { ok: true };
  }

  if (ackedMessages.length > MAX_PLATFORM_ACK_BATCH_SIZE) {
    throw new Error('TOO_MANY_ACKED_EVENT_IDS');
  }

  if (pool.dialect === 'turso') {
    for (const ackedMessageChunk of chunkItems(ackedMessages, TURSO_ACK_UPDATE_CHUNK_SIZE)) {
      const queryParams: unknown[] = [params.pluginId];
      const ackedMessageFilter = appendAckedMessageFilter(ackedMessageChunk, queryParams);
      const userFilter = appendUserIdFilter(params.userId, queryParams);
      await pool.query(
        `UPDATE chat_messages
            SET task_state = 'completed',
                metadata = json_patch(
                  COALESCE(metadata, '{}'),
                  json_object('pluginReadBy', json_object($1, CURRENT_TIMESTAMP))
                ),
                updated_at = CURRENT_TIMESTAMP
          WHERE (${ackedMessageFilter})
            AND role = 'user'
            AND task_state IN ('accepted', 'dispatched')${userFilter}`,
        queryParams,
      );
    }
    return { ok: true };
  }

  const messageIds = ackedMessages.map((item) => item.messageId);
  const writeSeqs = ackedMessages.map((item) => item.writeSeq);
  const queryParams: unknown[] = [messageIds, writeSeqs, params.pluginId];
  const userFilter = appendUserIdFilter(params.userId, queryParams);
  await pool.query(
    `UPDATE chat_messages
        SET task_state = 'completed',
            metadata = jsonb_set(
              COALESCE(metadata, '{}'::jsonb),
              '{pluginReadBy}',
              COALESCE(COALESCE(metadata, '{}'::jsonb)->'pluginReadBy', '{}'::jsonb)
                || jsonb_build_object($3, to_jsonb(CURRENT_TIMESTAMP)),
              true
            ),
            updated_at = CURRENT_TIMESTAMP
      WHERE (message_id, write_seq) IN (
        SELECT * FROM UNNEST($1::text[], $2::int[])
      )
        AND role = 'user'
        AND task_state IN ('accepted', 'dispatched')${userFilter}`,
    queryParams,
  );
  return { ok: true };
}

function parseAckedMessageEventId(eventId: string): { messageId: string; writeSeq: number } | null {
  const match = /^evt_msg_(.+)_(\d+)$/.exec(eventId.trim());
  if (!match) return null;
  const messageId = match[1].trim();
  const writeSeq = Number.parseInt(match[2], 10);
  if (!messageId || !Number.isFinite(writeSeq) || writeSeq <= 0) return null;
  return { messageId, writeSeq };
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
      taskState: input.role === 'assistant' ? 'dispatched' : null,
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
      taskState: row.role === 'assistant' ? 'completed' : null,
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

function appendAckedMessageFilter(
  ackedMessages: Array<{ messageId: string; writeSeq: number }>,
  queryParams: unknown[],
): string {
  return ackedMessages
    .map((item) => {
      const messageIdRef = `$${queryParams.push(item.messageId)}`;
      const writeSeqRef = `$${queryParams.push(item.writeSeq)}`;
      return `(message_id = ${messageIdRef} AND write_seq = ${writeSeqRef})`;
    })
    .join(' OR ');
}

function chunkItems<T>(items: readonly T[], chunkSize: number): T[][] {
  if (chunkSize <= 0) {
    throw new Error('INVALID_CHUNK_SIZE');
  }
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += chunkSize) {
    chunks.push(items.slice(index, index + chunkSize));
  }
  return chunks;
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
