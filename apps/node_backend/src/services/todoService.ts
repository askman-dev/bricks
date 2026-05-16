import pool from '../db/index.js';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

export interface TodoItem {
  id: string;
  userId: string;
  title: string;
  notes: string | null;
  isCompleted: boolean;
  displayOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateTodoInput {
  title: string;
  notes?: string | null;
  displayOrder?: number;
}

export interface UpdateTodoInput {
  title?: string;
  notes?: string | null;
  isCompleted?: boolean;
  displayOrder?: number;
}

// ---------------------------------------------------------------------------
// Row mapper
// ---------------------------------------------------------------------------

interface TodoRow {
  id: string;
  user_id: string;
  title: string;
  notes: string | null;
  is_completed: boolean;
  display_order: number;
  created_at: string;
  updated_at: string;
}

function toDto(row: TodoRow): TodoItem {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    notes: row.notes,
    isCompleted: row.is_completed,
    displayOrder: row.display_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

export async function listTodos(
  userId: string,
  options: { includeCompleted?: boolean } = {},
): Promise<TodoItem[]> {
  const { includeCompleted = true } = options;
  const result = await pool.query<TodoRow>(
    `SELECT id, user_id, title, notes, is_completed, display_order, created_at, updated_at
       FROM user_todos
      WHERE user_id = $1
        ${includeCompleted ? '' : 'AND is_completed = FALSE'}
      ORDER BY display_order ASC, created_at ASC`,
    [userId],
  );
  return result.rows.map(toDto);
}

export async function getTodo(userId: string, id: string): Promise<TodoItem | null> {
  const result = await pool.query<TodoRow>(
    `SELECT id, user_id, title, notes, is_completed, display_order, created_at, updated_at
       FROM user_todos
      WHERE user_id = $1 AND id = $2`,
    [userId, id],
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function createTodo(
  userId: string,
  input: CreateTodoInput,
): Promise<TodoItem> {
  const result = await pool.query<TodoRow>(
    `INSERT INTO user_todos (user_id, title, notes, display_order)
       VALUES ($1, $2, $3, $4)
       RETURNING id, user_id, title, notes, is_completed, display_order, created_at, updated_at`,
    [userId, input.title.trim(), input.notes ?? null, input.displayOrder ?? 0],
  );
  return toDto(result.rows[0]);
}

export async function updateTodo(
  userId: string,
  id: string,
  input: UpdateTodoInput,
): Promise<TodoItem | null> {
  // Build the SET clause dynamically from provided fields.
  const setClauses: string[] = [];
  const values: unknown[] = [userId, id];
  let idx = 3;

  if (input.title !== undefined) {
    setClauses.push(`title = $${idx++}`);
    values.push(input.title.trim());
  }
  if (input.notes !== undefined) {
    setClauses.push(`notes = $${idx++}`);
    values.push(input.notes);
  }
  if (input.isCompleted !== undefined) {
    setClauses.push(`is_completed = $${idx++}`);
    values.push(input.isCompleted);
  }
  if (input.displayOrder !== undefined) {
    setClauses.push(`display_order = $${idx++}`);
    values.push(input.displayOrder);
  }

  if (setClauses.length === 0) {
    return getTodo(userId, id);
  }

  const result = await pool.query<TodoRow>(
    `UPDATE user_todos
        SET ${setClauses.join(', ')}
      WHERE user_id = $1 AND id = $2
      RETURNING id, user_id, title, notes, is_completed, display_order, created_at, updated_at`,
    values,
  );
  return result.rows[0] ? toDto(result.rows[0]) : null;
}

export async function completeTodo(
  userId: string,
  id: string,
): Promise<TodoItem | null> {
  return updateTodo(userId, id, { isCompleted: true });
}

export async function deleteTodo(
  userId: string,
  id: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `DELETE FROM user_todos WHERE user_id = $1 AND id = $2`,
    [userId, id],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
