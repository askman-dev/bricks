import pool from '../db/index.js';

interface ChatChannelRow {
  channel_id: string;
  thread_id: string | null;
  scope_type: ChatChannelScopeType;
  display_name: string;
  source: ChatChannelSource;
  generated_name_attempted_at: string | null;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
}

export type ChatChannelScopeType = 'channel' | 'thread';

export type ChatChannelSource =
  | 'manual'
  | 'first_message_exact'
  | 'first_message_generated'
  | 'tool';

export interface ChatChannelSetting {
  channelId: string;
  threadId: string | null;
  scopeType: ChatChannelScopeType;
  displayName: string;
  source: ChatChannelSource;
  generatedNameAttemptedAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChatChannelInput {
  channelId: string;
  threadId?: string | null;
  displayName: string;
  source?: ChatChannelSource;
}

function normalizeThreadId(threadId?: string | null): string {
  const normalizedThreadId = threadId?.trim() ?? '';
  return normalizedThreadId === 'main' ? '' : normalizedThreadId;
}

function scopeTypeForThreadId(threadId: string): ChatChannelScopeType {
  return threadId ? 'thread' : 'channel';
}

function toDto(row: ChatChannelRow): ChatChannelSetting {
  return {
    channelId: row.channel_id,
    threadId: row.thread_id || null,
    scopeType: row.scope_type ?? scopeTypeForThreadId(row.thread_id ?? ''),
    displayName: row.display_name,
    source: row.source ?? 'manual',
    generatedNameAttemptedAt: row.generated_name_attempted_at,
    archivedAt: row.archived_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listChatChannels(
  userId: string,
): Promise<ChatChannelSetting[]> {
  const result = await pool.query<ChatChannelRow>(
    `SELECT channel_id, thread_id, scope_type, display_name, source,
            generated_name_attempted_at, archived_at, created_at, updated_at
       FROM chat_channels
      WHERE user_id = $1
        AND archived_at IS NULL
      ORDER BY channel_id ASC, thread_id ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function upsertChatChannel(
  userId: string,
  input: ChatChannelInput,
): Promise<ChatChannelSetting> {
  const threadId = normalizeThreadId(input.threadId);
  const source = input.source ?? 'manual';
  const scopeType = scopeTypeForThreadId(threadId);
  const result = await pool.query<ChatChannelRow>(
    `INSERT INTO chat_channels (user_id, channel_id, thread_id, scope_type, display_name, source, archived_at)
      VALUES ($1, $2, $3, $4, $5, $6, NULL)
      ON CONFLICT (user_id, channel_id, thread_id)
      DO UPDATE SET
        scope_type = EXCLUDED.scope_type,
        display_name = EXCLUDED.display_name,
        source = EXCLUDED.source,
        archived_at = NULL,
        generated_name_attempted_at = chat_channels.generated_name_attempted_at,
        updated_at = CURRENT_TIMESTAMP
      RETURNING channel_id, thread_id, scope_type, display_name, source,
                generated_name_attempted_at, archived_at, created_at, updated_at`,
    [userId, input.channelId, threadId, scopeType, input.displayName, source],
  );
  return toDto(result.rows[0]);
}

export async function archiveChatChannel(
  userId: string,
  input: ChatChannelInput,
): Promise<ChatChannelSetting> {
  const threadId = normalizeThreadId(input.threadId);
  const scopeType = scopeTypeForThreadId(threadId);
  const source = input.source ?? 'manual';
  const result = await pool.query<ChatChannelRow>(
    `INSERT INTO chat_channels (user_id, channel_id, thread_id, scope_type, display_name, source, archived_at)
      VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
      ON CONFLICT (user_id, channel_id, thread_id)
      DO UPDATE SET
        scope_type = EXCLUDED.scope_type,
        display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), chat_channels.display_name),
        archived_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
      RETURNING channel_id, thread_id, scope_type, display_name, source,
                generated_name_attempted_at, archived_at, created_at, updated_at`,
    [userId, input.channelId, threadId, scopeType, input.displayName, source],
  );
  return toDto(result.rows[0]);
}

export async function insertFirstMessageExactNameIfMissing(
  userId: string,
  input: {
    channelId: string;
    threadId: string;
    displayName: string;
  },
): Promise<ChatChannelSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelRow>(
    `INSERT INTO chat_channels (user_id, channel_id, thread_id, scope_type, display_name, source)
      VALUES ($1, $2, $3, 'thread', $4, 'first_message_exact')
      ON CONFLICT (user_id, channel_id, thread_id) DO NOTHING
      RETURNING channel_id, thread_id, scope_type, display_name, source,
                generated_name_attempted_at, archived_at, created_at, updated_at`,
    [userId, input.channelId, threadId, input.displayName],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function claimFirstMessageGeneratedNameAttempt(
  userId: string,
  input: {
    channelId: string;
    threadId: string;
  },
): Promise<ChatChannelSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelRow>(
    `UPDATE chat_channels
        SET generated_name_attempted_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3
        AND source = 'first_message_exact'
        AND generated_name_attempted_at IS NULL
        AND archived_at IS NULL
      RETURNING channel_id, thread_id, scope_type, display_name, source,
                generated_name_attempted_at, archived_at, created_at, updated_at`,
    [userId, input.channelId, threadId],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function completeFirstMessageGeneratedName(
  userId: string,
  input: {
    channelId: string;
    threadId: string;
    displayName: string;
  },
): Promise<ChatChannelSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelRow>(
    `UPDATE chat_channels
        SET display_name = $4,
            source = 'first_message_generated',
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3
        AND source = 'first_message_exact'
        AND generated_name_attempted_at IS NOT NULL
        AND archived_at IS NULL
      RETURNING channel_id, thread_id, scope_type, display_name, source,
                generated_name_attempted_at, archived_at, created_at, updated_at`,
    [userId, input.channelId, threadId, input.displayName],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}
