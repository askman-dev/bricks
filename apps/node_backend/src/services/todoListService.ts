import pool from '../db/index.js';
import { listTodos, type TodoItem } from './todoService.js';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

export interface TodoList {
  id: string;
  userId: string;
  title: string;
  notes: string | null;
  displayOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface TodoListWithItems extends TodoList {
  items: TodoItem[];
}

export interface CreateTodoListInput {
  title: string;
  notes?: string | null;
  displayOrder?: number;
}

export interface UpdateTodoListInput {
  title?: string;
  notes?: string | null;
  displayOrder?: number;
}

// ---------------------------------------------------------------------------
// Row mapper
// ---------------------------------------------------------------------------

interface TodoListRow {
  id: string;
  user_id: string;
  title: string;
  notes: string | null;
  display_order: number;
  created_at: string;
  updated_at: string;
}

function toDto(row: TodoListRow): TodoList {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    notes: row.notes,
    displayOrder: row.display_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

const SELECT_COLS =
  'id, user_id, title, notes, display_order, created_at, updated_at';

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

export async function listTodoLists(userId: string): Promise<TodoList[]> {
  const result = await pool.query<TodoListRow>(
    `SELECT ${SELECT_COLS}
       FROM asset_todo_lists
      WHERE user_id = $1
      ORDER BY display_order ASC, created_at ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function getTodoList(
  userId: string,
  listId: string,
): Promise<TodoListWithItems | null> {
  const result = await pool.query<TodoListRow>(
    `SELECT ${SELECT_COLS}
       FROM asset_todo_lists
      WHERE user_id = $1 AND id = $2`,
    [userId, listId],
  );
  if (!result.rows[0]) return null;
  const list = toDto(result.rows[0]);
  const items = await listTodos(userId, listId, { includeCompleted: true });
  return { ...list, items };
}

export async function createTodoList(
  userId: string,
  input: CreateTodoListInput,
): Promise<TodoList> {
  const result = await pool.query<TodoListRow>(
    `INSERT INTO asset_todo_lists (user_id, title, notes, display_order)
       VALUES ($1, $2, $3, $4)
       RETURNING ${SELECT_COLS}`,
    [userId, input.title.trim(), input.notes ?? null, input.displayOrder ?? 0],
  );
  return toDto(result.rows[0]);
}

export async function updateTodoList(
  userId: string,
  listId: string,
  input: UpdateTodoListInput,
): Promise<TodoList | null> {
  const setClauses: string[] = [];
  const values: unknown[] = [userId, listId];
  let idx = 3;

  if (input.title !== undefined) {
    setClauses.push(`title = $${idx++}`);
    values.push(input.title.trim());
  }
  if (input.notes !== undefined) {
    setClauses.push(`notes = $${idx++}`);
    values.push(input.notes);
  }
  if (input.displayOrder !== undefined) {
    setClauses.push(`display_order = $${idx++}`);
    values.push(input.displayOrder);
  }

  if (setClauses.length === 0) {
    const r = await pool.query<TodoListRow>(
      `SELECT ${SELECT_COLS} FROM asset_todo_lists WHERE user_id = $1 AND id = $2`,
      [userId, listId],
    );
    return r.rows[0] ? toDto(r.rows[0]) : null;
  }

  const result = await pool.query<TodoListRow>(
    `UPDATE asset_todo_lists
        SET ${setClauses.join(', ')}
      WHERE user_id = $1 AND id = $2
      RETURNING ${SELECT_COLS}`,
    values,
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function deleteTodoList(
  userId: string,
  listId: string,
): Promise<{ deleted: boolean }> {
  // Cascade in the DB (ON DELETE CASCADE) removes child asset_todos automatically.
  const result = await pool.query(
    `DELETE FROM asset_todo_lists WHERE user_id = $1 AND id = $2`,
    [userId, listId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
