import pool from '../db/index.js';

interface ChatChannelNameRow {
  channel_id: string;
  display_name: string;
  created_at: string;
  updated_at: string;
}

export interface ChatChannelNameSetting {
  channelId: string;
  displayName: string;
  createdAt: string;
  updatedAt: string;
}

export interface ChatChannelNameInput {
  channelId: string;
  displayName: string;
}

function toDto(row: ChatChannelNameRow): ChatChannelNameSetting {
  return {
    channelId: row.channel_id,
    displayName: row.display_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listChatChannelNames(
  userId: string,
): Promise<ChatChannelNameSetting[]> {
  const result = await pool.query<ChatChannelNameRow>(
    `SELECT channel_id, display_name, created_at, updated_at
       FROM chat_channel_names
      WHERE user_id = $1
      ORDER BY channel_id ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function upsertChatChannelName(
  userId: string,
  input: ChatChannelNameInput,
): Promise<ChatChannelNameSetting> {
  const result = await pool.query<ChatChannelNameRow>(
    `INSERT INTO chat_channel_names (user_id, channel_id, display_name)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id, channel_id)
      DO UPDATE SET
        display_name = EXCLUDED.display_name,
        updated_at = CURRENT_TIMESTAMP
      RETURNING channel_id, display_name, created_at, updated_at`,
    [userId, input.channelId, input.displayName],
  );
  return toDto(result.rows[0]);
}

export async function deleteChatChannelName(
  userId: string,
  channelId: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `DELETE FROM chat_channel_names
      WHERE user_id = $1
        AND channel_id = $2`,
    [userId, channelId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
