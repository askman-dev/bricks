import express from 'express';
import { authenticate, AuthRequest } from '../middleware/auth.js';
import {
  listTodos,
  createTodo,
  updateTodo,
  deleteTodo,
} from '../services/todoService.js';
import {
  listTables,
  createTable,
  getTable,
  addColumn,
  removeColumn,
  addRow,
  updateRow,
  deleteRow,
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
  return req.user!.id;
}

/** Validate a URL path parameter (already a string from express params). */
function validPathParam(value: string, maxLength = 255): string | null {
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= maxLength ? trimmed : null;
}

// ---------------------------------------------------------------------------
// Todos
// ---------------------------------------------------------------------------

router.get('/todos', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const includeCompleted = req.query.includeCompleted !== 'false';
  const todos = await listTodos(uid, { includeCompleted });
  res.json({ todos });
});

router.post('/todos', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const title = readString(req.body?.title);
  if (!title) {
    res.status(400).json({ error: 'title is required' });
    return;
  }
  const notes = typeof req.body?.notes === 'string' ? req.body.notes.trim() || null : null;
  const todo = await createTodo(uid, { title, notes });
  res.status(201).json(todo);
});

router.patch('/todos/:id', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const { id } = req.params;
  const patch: Record<string, unknown> = {};
  if (typeof req.body?.title === 'string') patch.title = req.body.title;
  if (req.body?.notes !== undefined) {
    // Validate notes: must be string or null; reject other types with 400.
    if (req.body.notes !== null && typeof req.body.notes !== 'string') {
      res.status(400).json({ error: 'notes must be a string or null' });
      return;
    }
    patch.notes = typeof req.body.notes === 'string' ? req.body.notes.trim() || null : null;
  }
  if (typeof req.body?.isCompleted === 'boolean') patch.isCompleted = req.body.isCompleted;
  if (typeof req.body?.displayOrder === 'number') patch.displayOrder = req.body.displayOrder;
  const todo = await updateTodo(uid, id, patch);
  if (!todo) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(todo);
});

router.delete('/todos/:id', async (req: AuthRequest, res) => {
  const uid = userId(req);
  const result = await deleteTodo(uid, req.params.id);
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
