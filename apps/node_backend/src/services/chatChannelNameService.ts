import pool from '../db/index.js';

interface ChatChannelNameRow {
  channel_id: string;
  thread_id: string | null;
  display_name: string;
  source: ChatChannelNameSource;
  generated_name_attempted_at: string | null;
  created_at: string;
  updated_at: string;
}

export type ChatChannelNameSource =
  | 'manual'
  | 'first_message_exact'
  | 'first_message_generated';

export interface ChatChannelNameSetting {
  channelId: string;
  threadId: string | null;
  displayName: string;
  source: ChatChannelNameSource;
  generatedNameAttemptedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChatChannelNameInput {
  channelId: string;
  threadId?: string | null;
  displayName: string;
  source?: ChatChannelNameSource;
}

function normalizeThreadId(threadId?: string | null): string {
  const normalizedThreadId = threadId?.trim() ?? "";
  return normalizedThreadId === "main" ? "" : normalizedThreadId;
}

function toDto(row: ChatChannelNameRow): ChatChannelNameSetting {
  return {
    channelId: row.channel_id,
    threadId: row.thread_id || null,
    displayName: row.display_name,
    source: row.source ?? 'manual',
    generatedNameAttemptedAt: row.generated_name_attempted_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listChatChannelNames(
  userId: string,
): Promise<ChatChannelNameSetting[]> {
  const result = await pool.query<ChatChannelNameRow>(
    `SELECT channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at
       FROM chat_channel_names
      WHERE user_id = $1
      ORDER BY channel_id ASC, thread_id ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function upsertChatChannelName(
  userId: string,
  input: ChatChannelNameInput,
): Promise<ChatChannelNameSetting> {
  const threadId = normalizeThreadId(input.threadId);
  const source = input.source ?? 'manual';
  const result = await pool.query<ChatChannelNameRow>(
    `INSERT INTO chat_channel_names (user_id, channel_id, thread_id, display_name, source)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (user_id, channel_id, thread_id)
      DO UPDATE SET
        display_name = EXCLUDED.display_name,
        source = EXCLUDED.source,
        generated_name_attempted_at = chat_channel_names.generated_name_attempted_at,
        updated_at = CURRENT_TIMESTAMP
      RETURNING channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at`,
    [userId, input.channelId, threadId, input.displayName, source],
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
): Promise<ChatChannelNameSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelNameRow>(
    `INSERT INTO chat_channel_names (user_id, channel_id, thread_id, display_name, source)
      VALUES ($1, $2, $3, $4, 'first_message_exact')
      ON CONFLICT (user_id, channel_id, thread_id) DO NOTHING
      RETURNING channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at`,
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
): Promise<ChatChannelNameSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelNameRow>(
    `UPDATE chat_channel_names
        SET generated_name_attempted_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3
        AND source = 'first_message_exact'
        AND generated_name_attempted_at IS NULL
      RETURNING channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at`,
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
): Promise<ChatChannelNameSetting | null> {
  const threadId = normalizeThreadId(input.threadId);
  if (!threadId) return null;
  const result = await pool.query<ChatChannelNameRow>(
    `UPDATE chat_channel_names
        SET display_name = $4,
            source = 'first_message_generated',
            updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3
        AND source = 'first_message_exact'
      RETURNING channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at`,
    [userId, input.channelId, threadId, input.displayName],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function deleteChatChannelName(
  userId: string,
  channelId: string,
  threadId?: string | null,
): Promise<{ deleted: boolean }> {
  const storageThreadId = normalizeThreadId(threadId);
  const result = await pool.query(
    `DELETE FROM chat_channel_names
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3`,
    [userId, channelId, storageThreadId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
