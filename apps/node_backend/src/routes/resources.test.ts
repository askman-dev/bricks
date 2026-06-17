import express from 'express';
import http from 'node:http';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { generateToken } from '../middleware/auth.js';
import resourcesRouter from './resources.js';
import { createHighlight } from '../services/textHighlightService.js';
import { batchAddRows } from '../services/assetTableService.js';
import { createNote, appendNoteLines } from '../services/noteService.js';

vi.mock('../services/todoService.js', () => ({
  listTodos: vi.fn(),
  createTodo: vi.fn(),
  updateTodo: vi.fn(),
  deleteTodo: vi.fn(),
}));

vi.mock('../services/todoListService.js', () => ({
  listTodoLists: vi.fn(),
  getTodoList: vi.fn(),
  createTodoList: vi.fn(),
  updateTodoList: vi.fn(),
  deleteTodoList: vi.fn(),
}));

vi.mock('../services/assetTableService.js', () => ({
  listTables: vi.fn(),
  createTable: vi.fn(),
  getTable: vi.fn(),
  addColumn: vi.fn(),
  removeColumn: vi.fn(),
  addRow: vi.fn(),
  updateRow: vi.fn(),
  deleteRow: vi.fn(),
  batchAddRows: vi.fn(),
}));

vi.mock('../services/textHighlightService.js', () => ({
  listHighlights: vi.fn(),
  listHighlightsByMessageId: vi.fn(),
  createHighlight: vi.fn(),
  deleteHighlight: vi.fn(),
}));

vi.mock('../services/noteService.js', () => ({
  MAX_NOTE_LINES: 10000,
  listNotes: vi.fn(),
  getNote: vi.fn(),
  createNote: vi.fn(),
  updateNote: vi.fn(),
  deleteNote: vi.fn(),
  readNoteLines: vi.fn(),
  appendNoteLines: vi.fn(),
  replaceNoteLines: vi.fn(),
  deleteNoteLines: vi.fn(),
}));

describe('resources routes', () => {
  let server: http.Server;
  let baseUrl: string;

  beforeEach(async () => {
    process.env.JWT_SECRET = 'test-secret';
    vi.mocked(createHighlight).mockResolvedValue({
      id: 'highlight-1',
      userId: 'user-1',
      messageId: 'msg-1',
      selectedText: 'selected',
      startOffset: 1,
      endOffset: 9,
      color: 'yellow',
      createdAt: '2026-05-19T00:00:00.000Z',
      updatedAt: '2026-05-19T00:00:00.000Z',
    });
    vi.mocked(createNote).mockResolvedValue({
      id: 'note-1',
      userId: 'user-1',
      title: 'Research',
      body: '# Research\n\nUseful finding',
      isPublished: true,
      lineCount: 3,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:00:00.000Z',
    });
    vi.mocked(appendNoteLines).mockResolvedValue({
      id: 'note-1',
      userId: 'user-1',
      title: 'Research',
      body: '# Research\n\nUseful finding\nMore',
      isPublished: true,
      lineCount: 4,
      createdAt: '2026-06-16T00:00:00.000Z',
      updatedAt: '2026-06-16T00:01:00.000Z',
    });

    const app = express();
    app.use(express.json());
    app.use('/api/resources', resourcesRouter);
    server = app.listen(0);
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    if (typeof address !== 'object' || address === null) {
      throw new Error('test server did not bind to a TCP port');
    }
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterEach(async () => {
    vi.clearAllMocks();
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  it('creates highlights with the authenticated user id', async () => {
    const token = generateToken('user-1');

    const response = await fetch(`${baseUrl}/api/resources/highlights`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messageId: 'msg-1',
        selectedText: 'selected',
        startOffset: 1,
        endOffset: 9,
        color: 'yellow',
      }),
    });

    expect(response.status).toBe(201);
    expect(await response.json()).toMatchObject({
      id: 'highlight-1',
      messageId: 'msg-1',
      selectedText: 'selected',
    });
    expect(createHighlight).toHaveBeenCalledWith('user-1', {
      messageId: 'msg-1',
      selectedText: 'selected',
      startOffset: 1,
      endOffset: 9,
      color: 'yellow',
    });
  });

  it('creates markdown notes with the authenticated user id', async () => {
    const token = generateToken('user-1');

    const response = await fetch(`${baseUrl}/api/resources/notes`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        title: 'Research',
        body: '# Research\n\nUseful finding',
      }),
    });

    expect(response.status).toBe(201);
    expect(await response.json()).toMatchObject({
      id: 'note-1',
      title: 'Research',
      body: '# Research\n\nUseful finding',
    });
    expect(createNote).toHaveBeenCalledWith('user-1', {
      title: 'Research',
      body: '# Research\n\nUseful finding',
      isPublished: true,
    });
  });

  it('returns 400 when appending note lines exceeds the line limit', async () => {
    const token = generateToken('user-1');
    vi.mocked(appendNoteLines).mockRejectedValueOnce(
      new Error('Note body cannot exceed 10000 lines'),
    );

    const response = await fetch(`${baseUrl}/api/resources/notes/note-1/lines/append`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ lines: ['More'] }),
    });

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({
      error: 'Note body cannot exceed 10000 lines',
    });
  });

  describe('POST /api/resources/tables/:resourceId/rows/batch', () => {
    const makeRow = (id: string, n: number) => ({
      id,
      resourceId: 'my-table',
      displayNumber: n,
      cellData: { name: `item-${n}` },
      isDeleted: false,
      createdAt: '2026-05-26T00:00:00.000Z',
      updatedAt: '2026-05-26T00:00:00.000Z',
    });

    it('returns 201 and inserted rows for a valid 2-item batch', async () => {
      const token = generateToken('user-1');
      vi.mocked(batchAddRows).mockResolvedValue([makeRow('r-1', 1), makeRow('r-2', 2)]);

      const response = await fetch(`${baseUrl}/api/resources/tables/my-table/rows/batch`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rows: [{ name: 'item-1' }, { name: 'item-2' }] }),
      });

      expect(response.status).toBe(201);
      const body = await response.json() as { rows: unknown[] };
      expect(body.rows).toHaveLength(2);
      expect(batchAddRows).toHaveBeenCalledWith('user-1', 'my-table', [
        { name: 'item-1' },
        { name: 'item-2' },
      ]);
    });

    it('sanitizes each batch row payload before inserting', async () => {
      const token = generateToken('user-1');
      vi.mocked(batchAddRows).mockResolvedValue([makeRow('r-1', 1), makeRow('r-2', 2)]);

      const response = await fetch(`${baseUrl}/api/resources/tables/my-table/rows/batch`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          rows: [
            { name: 'item-1', count: 2, active: true, extra: { nested: true } },
            { name: 'item-2', archived: null, tags: ['x'] },
          ],
        }),
      });

      expect(response.status).toBe(201);
      expect(batchAddRows).toHaveBeenCalledWith('user-1', 'my-table', [
        { name: 'item-1', count: '2', active: 'true' },
        { name: 'item-2', archived: null },
      ]);
    });

    it('returns 400 when rows array has fewer than 2 items', async () => {
      const token = generateToken('user-1');

      const response = await fetch(`${baseUrl}/api/resources/tables/my-table/rows/batch`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rows: [{ name: 'only-one' }] }),
      });

      expect(response.status).toBe(400);
      const body = await response.json() as { error: string };
      expect(body.error).toMatch(/2 to 10/);
    });

    it('returns 400 when rows array has more than 10 items', async () => {
      const token = generateToken('user-1');
      const rows = Array.from({ length: 11 }, (_, i) => ({ name: `item-${i}` }));

      const response = await fetch(`${baseUrl}/api/resources/tables/my-table/rows/batch`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rows }),
      });

      expect(response.status).toBe(400);
      const body = await response.json() as { error: string };
      expect(body.error).toMatch(/2 to 10/);
    });

    it('returns 400 when rows is not an array', async () => {
      const token = generateToken('user-1');

      const response = await fetch(`${baseUrl}/api/resources/tables/my-table/rows/batch`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rows: 'not-an-array' }),
      });

      expect(response.status).toBe(400);
    });
  });
});
