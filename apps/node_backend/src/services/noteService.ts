import pool from '../db/index.js';

export const MAX_NOTE_LINES = 10000;

export interface Note {
  id: string;
  userId: string;
  title: string;
  body: string;
  isPublished: boolean;
  lineCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface NoteSummary {
  id: string;
  userId: string;
  title: string;
  preview: string;
  isPublished: boolean;
  lineCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateNoteInput {
  title: string;
  body?: string;
  isPublished?: boolean;
}

export interface UpdateNoteInput {
  title?: string;
  body?: string;
  isPublished?: boolean;
}

export interface NoteLines {
  noteId: string;
  title: string;
  startLine: number;
  endLine: number;
  lineCount: number;
  lines: Array<{ lineNumber: number; text: string }>;
}

interface NoteRow {
  id: string;
  user_id: string;
  title: string;
  body: string | null;
  is_published: boolean | number | string;
  created_at: string;
  updated_at: string;
}

const currentTimestampSql = pool.dialect === 'turso' ? 'CURRENT_TIMESTAMP' : 'NOW()';

function parseBool(raw: NoteRow['is_published']): boolean {
  return raw === true || raw === 1 || raw === '1' || raw === 'true';
}

function splitLines(body: string): string[] {
  if (body.length === 0) return [];
  return body.split(/\r?\n/);
}

function lineCount(body: string): number {
  return splitLines(body).length;
}

function assertLineLimit(body: string): void {
  if (lineCount(body) > MAX_NOTE_LINES) {
    throw new Error(`Note body cannot exceed ${MAX_NOTE_LINES} lines`);
  }
}

function joinLines(lines: string[]): string {
  return lines.join('\n');
}

function toDto(row: NoteRow): Note {
  const body = row.body ?? '';
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    body,
    isPublished: parseBool(row.is_published),
    lineCount: lineCount(body),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toSummary(row: NoteRow): NoteSummary {
  const note = toDto(row);
  const normalized = note.body.trim().replace(/\s+/g, ' ');
  return {
    id: note.id,
    userId: note.userId,
    title: note.title,
    preview: normalized.length > 160 ? `${normalized.substring(0, 157)}...` : normalized,
    isPublished: note.isPublished,
    lineCount: note.lineCount,
    createdAt: note.createdAt,
    updatedAt: note.updatedAt,
  };
}

const SELECT_COLS = 'id, user_id, title, body, is_published, created_at, updated_at';

export async function listNotes(
  userId: string,
  options: { includeUnpublished?: boolean } = {},
): Promise<NoteSummary[]> {
  const includeUnpublished = options.includeUnpublished === true;
  const result = await pool.query<NoteRow>(
    `SELECT ${SELECT_COLS}
       FROM asset_notes
      WHERE user_id = $1
        AND ($2 OR is_published = TRUE)
      ORDER BY updated_at DESC, created_at DESC`,
    [userId, includeUnpublished],
  );
  return result.rows.map(toSummary);
}

export async function getNote(userId: string, noteId: string): Promise<Note | null> {
  const result = await pool.query<NoteRow>(
    `SELECT ${SELECT_COLS}
       FROM asset_notes
      WHERE user_id = $1 AND id = $2`,
    [userId, noteId],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function createNote(userId: string, input: CreateNoteInput): Promise<Note> {
  const body = input.body ?? '';
  assertLineLimit(body);
  const result = await pool.query<NoteRow>(
    `INSERT INTO asset_notes (user_id, title, body, is_published)
       VALUES ($1, $2, $3, $4)
       RETURNING ${SELECT_COLS}`,
    [userId, input.title.trim(), body, input.isPublished ?? true],
  );
  return toDto(result.rows[0]);
}

export async function updateNote(
  userId: string,
  noteId: string,
  input: UpdateNoteInput,
): Promise<Note | null> {
  const setClauses: string[] = [];
  const values: unknown[] = [userId, noteId];
  let idx = 3;

  if (input.title !== undefined) {
    setClauses.push(`title = $${idx++}`);
    values.push(input.title.trim());
  }
  if (input.body !== undefined) {
    assertLineLimit(input.body);
    setClauses.push(`body = $${idx++}`);
    values.push(input.body);
  }
  if (input.isPublished !== undefined) {
    setClauses.push(`is_published = $${idx++}`);
    values.push(input.isPublished);
  }

  if (setClauses.length === 0) {
    return getNote(userId, noteId);
  }

  const result = await pool.query<NoteRow>(
    `UPDATE asset_notes
        SET ${setClauses.join(', ')}, updated_at = ${currentTimestampSql}
      WHERE user_id = $1 AND id = $2
      RETURNING ${SELECT_COLS}`,
    values,
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function deleteNote(
  userId: string,
  noteId: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `DELETE FROM asset_notes WHERE user_id = $1 AND id = $2`,
    [userId, noteId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}

export async function readNoteLines(
  userId: string,
  noteId: string,
  startLine = 1,
  endLine?: number,
): Promise<NoteLines | null> {
  const note = await getNote(userId, noteId);
  if (!note) return null;
  const lines = splitLines(note.body);
  const safeStart = Math.max(1, Math.trunc(startLine));
  const safeEnd = Math.min(lines.length, Math.trunc(endLine ?? safeStart));
  const selected = safeEnd >= safeStart ? lines.slice(safeStart - 1, safeEnd) : [];
  return {
    noteId: note.id,
    title: note.title,
    startLine: safeStart,
    endLine: safeEnd,
    lineCount: lines.length,
    lines: selected.map((text, index) => ({ lineNumber: safeStart + index, text })),
  };
}

export async function appendNoteLines(
  userId: string,
  noteId: string,
  linesToAppend: string[],
): Promise<Note | null> {
  const note = await getNote(userId, noteId);
  if (!note) return null;
  const existing = splitLines(note.body);
  const nextLines = [...existing, ...linesToAppend];
  const nextBody = joinLines(nextLines);
  assertLineLimit(nextBody);
  return updateNote(userId, noteId, { body: nextBody });
}

export async function replaceNoteLines(
  userId: string,
  noteId: string,
  startLine: number,
  endLine: number,
  replacementLines: string[],
): Promise<Note | null> {
  const note = await getNote(userId, noteId);
  if (!note) return null;
  const existing = splitLines(note.body);
  const start = Math.max(1, Math.trunc(startLine));
  const end = Math.max(start, Math.trunc(endLine));
  if (start > existing.length + 1) {
    throw new Error('startLine cannot be greater than the next append line');
  }
  const nextLines = [
    ...existing.slice(0, start - 1),
    ...replacementLines,
    ...existing.slice(end),
  ];
  const nextBody = joinLines(nextLines);
  assertLineLimit(nextBody);
  return updateNote(userId, noteId, { body: nextBody });
}

export async function deleteNoteLines(
  userId: string,
  noteId: string,
  startLine: number,
  endLine: number,
): Promise<Note | null> {
  return replaceNoteLines(userId, noteId, startLine, endLine, []);
}
