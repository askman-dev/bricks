import pool from '../db/index.js';

interface ChatChannelNameRow {
  channel_id: string;
  thread_id: string | null;
  display_name: string;
  created_at: string;
  updated_at: string;
}

export interface ChatChannelNameSetting {
  channelId: string;
  threadId: string | null;
  displayName: string;
  createdAt: string;
  updatedAt: string;
}

export interface ChatChannelNameInput {
  channelId: string;
  threadId?: string | null;
  displayName: string;
}

function toDto(row: ChatChannelNameRow): ChatChannelNameSetting {
  return {
    channelId: row.channel_id,
    threadId: row.thread_id || null,
    displayName: row.display_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listChatChannelNames(
  userId: string,
): Promise<ChatChannelNameSetting[]> {
  const result = await pool.query<ChatChannelNameRow>(
    `SELECT channel_id, thread_id, display_name, created_at, updated_at
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
  const threadId = input.threadId?.trim() ?? "";
  const result = await pool.query<ChatChannelNameRow>(
    `INSERT INTO chat_channel_names (user_id, channel_id, thread_id, display_name)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (user_id, channel_id, thread_id)
      DO UPDATE SET
        display_name = EXCLUDED.display_name,
        updated_at = CURRENT_TIMESTAMP
      RETURNING channel_id, thread_id, display_name, created_at, updated_at`,
    [userId, input.channelId, threadId, input.displayName],
  );
  return toDto(result.rows[0]);
}

export async function deleteChatChannelName(
  userId: string,
  channelId: string,
  threadId?: string | null,
): Promise<{ deleted: boolean }> {
  const storageThreadId = threadId?.trim() ?? "";
  const result = await pool.query(
    `DELETE FROM chat_channel_names
      WHERE user_id = $1
        AND channel_id = $2
        AND thread_id = $3`,
    [userId, channelId, storageThreadId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
