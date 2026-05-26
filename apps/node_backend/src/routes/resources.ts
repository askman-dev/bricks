import express from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  listTodos,
  createTodo,
  updateTodo,
  deleteTodo,
} from '../services/todoService.js';
import {
  listTodoLists,
  getTodoList,
  createTodoList,
  updateTodoList,
  deleteTodoList,
} from '../services/todoListService.js';
import {
  listTables,
  createTable,
  getTable,
  addColumn,
  removeColumn,
  addRow,
  updateRow,
  deleteRow,
  batchAddRows,
} from '../services/assetTableService.js';
import {
  listHighlights,
  listHighlightsByMessageId,
  createHighlight,
  deleteHighlight,
} from '../services/textHighlightService.js';

const router = express.Router();
router.use(authenticate);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readString(value: unknown, maxLength = 4096): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > maxLength) return null;
  return trimmed;
}

function userId(req: AuthRequest): string {
  const uid = req.userId;
  if (!uid) {
    throw new Error('Authenticated request is missing userId');
  }
  return uid;
}

/** Validate a URL path parameter (already a string from express params). */
function validPathParam(value: string, maxLength = 255): string | null {
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= maxLength ? trimmed : null;
}

// ---------------------------------------------------------------------------
// Todo Lists (parent entities) + Todo Items (nested under a list)
// ---------------------------------------------------------------------------

router.get('/todo-lists', async (req: AuthRequest, res) => {
  const lists = await listTodoLists(userId(req));
  res.json({ lists });
});

router.post('/todo-lists', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const title = readString(req.body?.title);
  if (!title) {
    res.status(400).json({ error: 'title is required' });
    return;
  }
  const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() || null : null;
  const list = await createTodoList(uid, { title, notes });
  res.status(201).json(list);
});

router.get('/todo-lists/:listId', async (req: AuthRequest, res) => {
  const listId = validPathParam(req.params.listId);
  if (!listId) {
    res.status(400).json({ error: 'listId is invalid' });
    return;
  }
  const list = await getTodoList(userId(req), listId);
  if (!list) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(list);
});

router.patch('/todo-lists/:listId', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const listId = validPathParam(req.params.listId);
  if (!listId) {
    res.status(400).json({ error: 'listId is invalid' });
    return;
  }
  const patch: { title?: string; notes?: string | null } = {};
  if (typeof req.body?.title === 'string') patch.title = req.body.title;
  if (req.body?.notes !== undefined) {
    if (req.body.notes !== null && typeof req.body.notes !== 'string') {
      res.status(400).json({ error: 'notes must be a string or null' });
      return;
    }
    patch.notes = typeof req.body.notes === 'string' ? req.body.notes.trim() || null : null;
  }
  const list = await updateTodoList(uid, listId, patch);
  if (!list) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(list);
});

router.delete('/todo-lists/:listId', async (req: AuthRequest, res) => {
  const listId = validPathParam(req.params.listId);
  if (!listId) {
    res.status(400).json({ error: 'listId is invalid' });
    return;
  }
  const result = await deleteTodoList(userId(req), listId);
  res.json(result);
});

// --- Todo items nested under a list ---

router.get('/todo-lists/:listId/todos', async (req: AuthRequest, res) => {
  const listId = validPathParam(req.params.listId);
  if (!listId) {
    res.status(400).json({ error: 'listId is invalid' });
    return;
  }
  const uid = userId(req);
  const includeCompleted = req.query.includeCompleted !== 'false';
  const todos = await listTodos(uid, listId, { includeCompleted });
  res.json({ todos });
});

router.post('/todo-lists/:listId/todos', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const listId = validPathParam(req.params.listId);
  if (!listId) {
    res.status(400).json({ error: 'listId is invalid' });
    return;
  }
  const title = readString(req.body?.title);
  if (!title) {
    res.status(400).json({ error: 'title is required' });
    return;
  }
  const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() || null : null;
  const todo = await createTodo(uid, listId, { title, notes });
  res.status(201).json(todo);
});

router.patch('/todo-lists/:listId/todos/:id', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const listId = validPathParam(req.params.listId);
  const id = validPathParam(req.params.id);
  if (!listId || !id) {
    res.status(400).json({ error: 'listId and id are invalid' });
    return;
  }
  const patch: Record<string, unknown> = {};
  if (typeof req.body?.title === 'string') patch.title = req.body.title;
  if (req.body?.notes !== undefined) {
    if (req.body.notes !== null && typeof req.body.notes !== 'string') {
      res.status(400).json({ error: 'notes must be a string or null' });
      return;
    }
    patch.notes = typeof req.body.notes === 'string' ? req.body.notes.trim() || null : null;
  }
  if (typeof req.body?.isCompleted === 'boolean') patch.isCompleted = req.body.isCompleted;
  if (typeof req.body?.displayOrder === 'number') patch.displayOrder = req.body.displayOrder;
  const todo = await updateTodo(uid, listId, id, patch);
  if (!todo) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(todo);
});

router.delete('/todo-lists/:listId/todos/:id', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const listId = validPathParam(req.params.listId);
  const id = validPathParam(req.params.id);
  if (!listId || !id) {
    res.status(400).json({ error: 'listId and id are invalid' });
    return;
  }
  const result = await deleteTodo(uid, listId, id);
  res.json(result);
});

// ---------------------------------------------------------------------------
// Asset tables
// ---------------------------------------------------------------------------

router.get('/tables', async (req: AuthRequest, res) => {
  const tables = await listTables(userId(req));
  res.json({ tables });
});

router.post('/tables', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = readString(req.body?.resourceId, 255);
  const title = readString(req.body?.title);
  if (!resourceId || !title) {
    res.status(400).json({ error: 'resourceId and title are required' });
    return;
  }
  const table = await createTable(uid, { resourceId, title });
  res.status(201).json(table);
});

router.get('/tables/:resourceId', async (req: AuthRequest, res) => {
  const resourceId = validPathParam(req.params.resourceId);
  if (!resourceId) {
    res.status(400).json({ error: 'resourceId is invalid' });
    return;
  }
  const table = await getTable(userId(req), resourceId);
  if (!table) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(table);
});

router.post('/tables/:resourceId/columns', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  if (!resourceId) {
    res.status(400).json({ error: 'resourceId is invalid' });
    return;
  }
  const columnKey = readString(req.body?.columnKey, 255);
  const displayName = readString(req.body?.displayName);
  if (!columnKey || !displayName) {
    res.status(400).json({ error: 'columnKey and displayName are required' });
    return;
  }
  const columnOrder = typeof req.body?.columnOrder === 'number' ? Math.trunc(req.body.columnOrder) : 0;
  const col = await addColumn(uid, resourceId, { columnKey, displayName, columnOrder });
  res.status(201).json(col);
});

router.delete('/tables/:resourceId/columns/:columnKey', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  const columnKey = validPathParam(req.params.columnKey);
  if (!resourceId || !columnKey) {
    res.status(400).json({ error: 'resourceId and columnKey are invalid' });
    return;
  }
  const result = await removeColumn(uid, resourceId, columnKey);
  res.json(result);
});

router.post('/tables/:resourceId/rows', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  if (!resourceId) {
    res.status(400).json({ error: 'resourceId is invalid' });
    return;
  }
  const cellData: Record<string, string | null> =
    req.body?.cellData && typeof req.body.cellData === 'object' && !Array.isArray(req.body.cellData)
      ? (req.body.cellData as Record<string, string | null>)
      : {};
  const row = await addRow(uid, resourceId, cellData);
  res.status(201).json(row);
});

router.post('/tables/:resourceId/rows/batch', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  if (!resourceId) {
    res.status(400).json({ error: 'resourceId is invalid' });
    return;
  }
  const rawRows = req.body?.rows;
  if (!Array.isArray(rawRows) || rawRows.length < 2 || rawRows.length > 10) {
    res.status(400).json({ error: 'rows must be an array with 2 to 10 items' });
    return;
  }
  const cellDataArray: Array<Record<string, string | null>> = rawRows.map((item: unknown) => {
    if (item && typeof item === 'object' && !Array.isArray(item)) {
      return item as Record<string, string | null>;
    }
    return {};
  });
  const rows = await batchAddRows(uid, resourceId, cellDataArray);
  res.status(201).json({ rows });
});

router.patch('/tables/:resourceId/rows/:rowId', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  const rowId = validPathParam(req.params.rowId);
  if (!resourceId || !rowId) {
    res.status(400).json({ error: 'resourceId and rowId are invalid' });
    return;
  }
  const cellData: Record<string, string | null> =
    req.body?.cellData && typeof req.body.cellData === 'object' && !Array.isArray(req.body.cellData)
      ? (req.body.cellData as Record<string, string | null>)
      : {};
  const row = await updateRow(uid, resourceId, rowId, cellData);
  if (!row) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(row);
});

router.delete('/tables/:resourceId/rows/:rowId', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const resourceId = validPathParam(req.params.resourceId);
  const rowId = validPathParam(req.params.rowId);
  if (!resourceId || !rowId) {
    res.status(400).json({ error: 'resourceId and rowId are invalid' });
    return;
  }
  const result = await deleteRow(uid, resourceId, rowId);
  res.json(result);
});

// ---------------------------------------------------------------------------
// Text highlights
// ---------------------------------------------------------------------------

router.get('/highlights', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const messageId = typeof req.query.messageId === 'string' ? req.query.messageId : null;
  const highlights = messageId
    ? await listHighlightsByMessageId(uid, messageId)
    : await listHighlights(uid);
  res.json({ highlights });
});

router.post('/highlights', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const messageId = readString(req.body?.messageId, 255);
  const selectedText = readString(req.body?.selectedText, 65535);
  if (!messageId || !selectedText) {
    res.status(400).json({ error: 'messageId and selectedText are required' });
    return;
  }
  const highlight = await createHighlight(uid, {
    messageId,
    selectedText,
    startOffset: typeof req.body?.startOffset === 'number' ? Math.trunc(req.body.startOffset) : null,
    endOffset: typeof req.body?.endOffset === 'number' ? Math.trunc(req.body.endOffset) : null,
    color: readString(req.body?.color, 32) ?? 'yellow',
  });
  res.status(201).json(highlight);
});

router.delete('/highlights/:id', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const result = await deleteHighlight(uid, req.params.id);
  res.json(result);
});

export default router;
