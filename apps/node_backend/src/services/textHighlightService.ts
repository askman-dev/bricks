import pool from '../db/index.js';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

export interface TextHighlight {
  id: string;
  userId: string;
  messageId: string;
  selectedText: string;
  startOffset: number | null;
  endOffset: number | null;
  color: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateHighlightInput {
  messageId: string;
  selectedText: string;
  startOffset?: number | null;
  endOffset?: number | null;
  color?: string;
}

// ---------------------------------------------------------------------------
// Row mapper
// ---------------------------------------------------------------------------

interface HighlightRow {
  id: string;
  user_id: string;
  message_id: string;
  selected_text: string;
  start_offset: number | null;
  end_offset: number | null;
  color: string;
  created_at: string;
  updated_at: string;
}

function toDto(row: HighlightRow): TextHighlight {
  return {
    id: row.id,
    userId: row.user_id,
    messageId: row.message_id,
    selectedText: row.selected_text,
    startOffset: row.start_offset,
    endOffset: row.end_offset,
    color: row.color,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

export async function listHighlights(userId: string): Promise<TextHighlight[]> {
  const result = await pool.query<HighlightRow>(
    `SELECT id, user_id, message_id, selected_text, start_offset, end_offset, color, created_at, updated_at
       FROM text_highlights
      WHERE user_id = $1
      ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function listHighlightsByMessageId(
  userId: string,
  messageId: string,
): Promise<TextHighlight[]> {
  const result = await pool.query<HighlightRow>(
    `SELECT id, user_id, message_id, selected_text, start_offset, end_offset, color, created_at, updated_at
       FROM text_highlights
      WHERE user_id = $1 AND message_id = $2
      ORDER BY start_offset ASC NULLS LAST, created_at ASC`,
    [userId, messageId],
  );
  return result.rows.map(toDto);
}

export async function createHighlight(
  userId: string,
  input: CreateHighlightInput,
): Promise<TextHighlight> {
  const result = await pool.query<HighlightRow>(
    `INSERT INTO text_highlights
        (user_id, message_id, selected_text, start_offset, end_offset, color)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, user_id, message_id, selected_text, start_offset, end_offset, color, created_at, updated_at`,
    [
      userId,
      input.messageId,
      input.selectedText,
      input.startOffset ?? null,
      input.endOffset ?? null,
      input.color ?? 'yellow',
    ],
  );
  return toDto(result.rows[0]);
}

export async function deleteHighlight(
  userId: string,
  id: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `DELETE FROM text_highlights WHERE user_id = $1 AND id = $2`,
    [userId, id],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
