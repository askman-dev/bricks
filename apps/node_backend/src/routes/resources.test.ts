import express from 'express';
import http from 'node:http';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { generateToken } from '../middleware/auth.js';
import resourcesRouter from './resources.js';
import { createHighlight } from '../services/textHighlightService.js';

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
}));

vi.mock('../services/textHighlightService.js', () => ({
  listHighlights: vi.fn(),
  listHighlightsByMessageId: vi.fn(),
  createHighlight: vi.fn(),
  deleteHighlight: vi.fn(),
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
});
