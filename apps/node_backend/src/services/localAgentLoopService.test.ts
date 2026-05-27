import { describe, expect, it, vi, beforeEach } from 'vitest';

const upsertChatScopeSettingMock = vi.fn();
const upsertChatChannelNameMock = vi.fn();
const listChatScopeSettingsMock = vi.fn().mockResolvedValue([]);
const listChatChannelNamesMock = vi.fn().mockResolvedValue([]);

vi.mock('./chatRouterService.js', () => ({
  CHAT_ROUTER_LOCAL: 'local',
  buildChatSessionId: (channelId: string, threadId?: string | null) =>
    `session:${channelId}:${threadId ?? 'main'}`,
  normalizeChatThreadId: (threadId?: string | null) => {
    const t = threadId?.trim();
    return t && t.length > 0 ? t : 'main';
  },
  upsertChatScopeSetting: upsertChatScopeSettingMock,
  listChatScopeSettings: listChatScopeSettingsMock,
}));

vi.mock('./chatChannelNameService.js', () => ({
  upsertChatChannelName: upsertChatChannelNameMock,
  listChatChannelNames: listChatChannelNamesMock,
}));

vi.mock('./todoService.js', () => ({
  listTodos: vi.fn().mockResolvedValue([]),
  createTodo: vi.fn().mockResolvedValue({ id: 'todo-1', listId: 'list-1', title: 'Test', isCompleted: false }),
  updateTodo: vi.fn().mockResolvedValue(null),
  completeTodo: vi.fn().mockResolvedValue(null),
  deleteTodo: vi.fn().mockResolvedValue({ deleted: false }),
}));

vi.mock('./todoListService.js', () => ({
  listTodoLists: vi.fn().mockResolvedValue([]),
  getTodoList: vi.fn().mockResolvedValue(null),
  createTodoList: vi.fn().mockResolvedValue({ id: 'list-1', title: 'Work', notes: null }),
  updateTodoList: vi.fn().mockResolvedValue(null),
  deleteTodoList: vi.fn().mockResolvedValue({ deleted: false }),
}));

vi.mock('./assetTableService.js', () => ({
  listTables: vi.fn().mockResolvedValue([]),
  createTable: vi.fn().mockResolvedValue({ id: 'tbl-1', resourceId: 'tasks', title: 'Tasks' }),
  getTable: vi.fn().mockResolvedValue(null),
  addColumn: vi.fn().mockResolvedValue({ id: 'col-1', columnKey: 'name', displayName: 'Name' }),
  removeColumn: vi.fn().mockResolvedValue({ deleted: false }),
  addRow: vi.fn().mockResolvedValue({ id: 'row-1', displayNumber: 1, cellData: {} }),
  batchAddRows: vi.fn().mockResolvedValue([]),
  updateRow: vi.fn().mockResolvedValue(null),
  deleteRow: vi.fn().mockResolvedValue({ deleted: false }),
}));

vi.mock('./textHighlightService.js', () => ({
  listHighlights: vi.fn().mockResolvedValue([]),
  listHighlightsByMessageId: vi.fn().mockResolvedValue([]),
  createHighlight: vi.fn().mockResolvedValue({ id: 'hl-1', selectedText: 'hello' }),
  deleteHighlight: vi.fn().mockResolvedValue({ deleted: false }),
}));

describe('localAgentLoopService', () => {
  beforeEach(() => {
    upsertChatScopeSettingMock.mockReset();
    upsertChatChannelNameMock.mockReset();
  });

  it('rejects tools outside allowlist', async () => {
    const { executeInternalTool } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: 'chat.external.exec',
      args: {},
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('tool_not_allowed');
  });

  it('persists channel instruction update tool', async () => {
    upsertChatScopeSettingMock.mockResolvedValue({
      scopeType: 'channel',
      channelId: 'default',
      threadId: null,
      instructions: 'Keep concise',
      updatedAt: '2026-05-09T00:00:00.000Z',
    });

    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
      args: {
        channelId: 'default',
        instruction: 'Keep concise',
      },
    });

    expect(result.ok).toBe(true);
    expect(upsertChatScopeSettingMock).toHaveBeenCalledWith('u-1', {
      scopeType: 'channel',
      channelId: 'default',
      threadId: null,
      router: 'local',
      instructions: 'Keep concise',
    });
  });

  it('creates channel scope for create tool', async () => {
    upsertChatScopeSettingMock.mockResolvedValue({});

    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
      args: { channelId: 'ops' },
    });

    expect(result.ok).toBe(true);
    expect(result.data?.sessionId).toBe('session:ops:main');
  });

  it('creates thread scope for create tool', async () => {
    upsertChatScopeSettingMock.mockResolvedValue({});

    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_THREAD_CREATE,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_THREAD_CREATE,
      args: {
        channelId: 'ops',
        threadId: 'bugs',
      },
    });

    expect(result.ok).toBe(true);
    expect(result.data?.sessionId).toBe('session:ops:bugs');
  });

  it('runs tool calls in sequence and stops on failure', async () => {
    upsertChatScopeSettingMock
      .mockResolvedValueOnce({ scopeType: 'channel', channelId: 'ops', threadId: null, instructions: 'a', updatedAt: 'x' })
      .mockResolvedValueOnce({});

    const {
      executeInternalToolSequence,
      INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalToolSequence({
      userId: 'u-1',
      calls: [
        {
          toolName: INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
          args: { channelId: 'ops', instruction: 'a' },
        },
        {
          toolName: 'chat.unknown.tool',
          args: {},
        },
      ],
    });

    expect(result.ok).toBe(false);
    expect(result.completedCalls).toBe(1);
    expect(result.failedCall?.error?.code).toBe('tool_not_allowed');
  });

  it('rejects channelId longer than 255 chars for channel instruction set tool', async () => {
    const { executeInternalTool, INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
      args: {
        channelId: 'a'.repeat(256),
        instruction: 'Keep concise',
      },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('rejects threadId "main" for thread instruction set tool', async () => {
    const { executeInternalTool, INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
      args: {
        channelId: 'default',
        threadId: 'main',
        instruction: 'Keep concise',
      },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('does not infer thread instruction tool call when threadId is main', async () => {
    const { inferInternalToolCallsFromMessage } = await import('./localAgentLoopService.js');

    const calls = inferInternalToolCallsFromMessage({
      message: '/thread instruction Be concise',
      channelId: 'ops',
      threadId: 'main',
    });

    expect(calls).toEqual([]);
  });

  it('does not infer thread instruction tool call when threadId is undefined', async () => {
    const { inferInternalToolCallsFromMessage } = await import('./localAgentLoopService.js');

    const calls = inferInternalToolCallsFromMessage({
      message: '/thread instruction Be concise',
      channelId: 'ops',
    });

    expect(calls).toEqual([]);
  });

  it('renames a channel via chat_channel_rename tool', async () => {
    upsertChatChannelNameMock.mockResolvedValue({
      channelId: 'default',
      displayName: 'My Channel',
      createdAt: '2026-05-09T00:00:00.000Z',
      updatedAt: '2026-05-09T01:00:00.000Z',
    });

    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
      args: { channelId: 'default', displayName: 'My Channel' },
    });

    expect(result.ok).toBe(true);
    expect(result.data?.channelId).toBe('default');
    expect(result.data?.displayName).toBe('My Channel');
    expect(upsertChatChannelNameMock).toHaveBeenCalledWith('u-1', {
      channelId: 'default',
      displayName: 'My Channel',
    });
  });

  it('rejects rename when channelId or displayName is missing', async () => {
    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
      args: { channelId: 'default' },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('renames a thread via chat_thread_rename tool', async () => {
    upsertChatChannelNameMock.mockResolvedValue({
      channelId: 'default',
      threadId: 'bugs',
      displayName: 'Bug Reports',
      createdAt: '2026-05-09T00:00:00.000Z',
      updatedAt: '2026-05-09T01:00:00.000Z',
    });

    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_THREAD_RENAME,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_THREAD_RENAME,
      args: { channelId: 'default', threadId: 'bugs', displayName: 'Bug Reports' },
    });

    expect(result.ok).toBe(true);
    expect(result.data?.channelId).toBe('default');
    expect(result.data?.threadId).toBe('bugs');
    expect(result.data?.displayName).toBe('Bug Reports');
    expect(upsertChatChannelNameMock).toHaveBeenCalledWith('u-1', {
      channelId: 'default',
      threadId: 'bugs',
      displayName: 'Bug Reports',
    });
  });

  it('rejects thread rename when any required arg is missing', async () => {
    const {
      executeInternalTool,
      INTERNAL_TOOL_CHAT_THREAD_RENAME,
    } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_CHAT_THREAD_RENAME,
      args: { channelId: 'default', threadId: 'bugs' },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('infers tool calls from slash-like user commands', async () => {
    const { inferInternalToolCallsFromMessage } = await import('./localAgentLoopService.js');

    const calls = inferInternalToolCallsFromMessage({
      message: '/thread create bugs',
      channelId: 'ops',
      threadId: 'main',
    });

    expect(calls).toEqual([
      {
        toolName: 'chat.thread.create',
        args: { channelId: 'ops', threadId: 'bugs' },
      },
    ]);
  });

  // -------------------------------------------------------------------------
  // Todo list tool tests
  // -------------------------------------------------------------------------

  it('dispatches todolist_create and returns the created list', async () => {
    const { createTodoList } = await import('./todoListService.js');
    (createTodoList as ReturnType<typeof vi.fn>).mockResolvedValue({
      id: 'list-99',
      userId: 'u-1',
      title: 'Work tasks',
      notes: null,
      displayOrder: 0,
      createdAt: '2026-05-16T00:00:00.000Z',
      updatedAt: '2026-05-16T00:00:00.000Z',
    });

    const { executeInternalTool, INTERNAL_TOOL_TODO_LIST_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_LIST_CREATE,
      args: { title: 'Work tasks' },
    });

    expect(result.ok).toBe(true);
    expect(result.data).toMatchObject({ id: 'list-99', title: 'Work tasks' });
    expect(createTodoList).toHaveBeenCalledWith('u-1', { title: 'Work tasks', notes: null });
  });

  it('returns invalid_args when todolist_create receives no title', async () => {
    const { executeInternalTool, INTERNAL_TOOL_TODO_LIST_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_LIST_CREATE,
      args: {},
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('dispatches todolist_list and returns lists', async () => {
    const { listTodoLists } = await import('./todoListService.js');
    (listTodoLists as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'list-1', title: 'Work', notes: null },
    ]);

    const { executeInternalTool, INTERNAL_TOOL_TODO_LIST_LIST } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_LIST_LIST,
      args: {},
    });

    expect(result.ok).toBe(true);
    expect((result.data as { lists: unknown[] }).lists).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Todo item tool tests
  // -------------------------------------------------------------------------

  it('dispatches todo_create with listId and returns the created todo', async () => {
    const { createTodo } = await import('./todoService.js');
    (createTodo as ReturnType<typeof vi.fn>).mockResolvedValue({
      id: 'todo-42',
      userId: 'u-1',
      listId: 'list-1',
      title: 'Buy milk',
      notes: null,
      isCompleted: false,
      displayOrder: 0,
      createdAt: '2026-05-16T00:00:00.000Z',
      updatedAt: '2026-05-16T00:00:00.000Z',
    });

    const { executeInternalTool, INTERNAL_TOOL_TODO_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_CREATE,
      args: { listId: 'list-1', title: 'Buy milk' },
    });

    expect(result.ok).toBe(true);
    expect(result.data).toMatchObject({ id: 'todo-42', title: 'Buy milk' });
    expect(createTodo).toHaveBeenCalledWith('u-1', 'list-1', { title: 'Buy milk', notes: null });
  });

  it('returns invalid_args when todo_create is missing listId', async () => {
    const { executeInternalTool, INTERNAL_TOOL_TODO_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_CREATE,
      args: { title: 'Buy milk' },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('returns invalid_args when todo_create is missing title', async () => {
    const { executeInternalTool, INTERNAL_TOOL_TODO_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TODO_CREATE,
      args: {},
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  // -------------------------------------------------------------------------
  // Asset table tool tests
  // -------------------------------------------------------------------------

  it('dispatches table_create and returns the created table', async () => {
    const { createTable } = await import('./assetTableService.js');
    (createTable as ReturnType<typeof vi.fn>).mockResolvedValue({
      id: 'tbl-99',
      userId: 'u-1',
      resourceId: 'tasks',
      title: 'My Tasks',
      createdAt: '2026-05-16T00:00:00.000Z',
      updatedAt: '2026-05-16T00:00:00.000Z',
    });

    const { executeInternalTool, INTERNAL_TOOL_TABLE_CREATE } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_CREATE,
      args: { resourceId: 'tasks', title: 'My Tasks' },
    });

    expect(result.ok).toBe(true);
    expect(result.data).toMatchObject({ resourceId: 'tasks', title: 'My Tasks' });
  });

  it('sanitizes non-string cellData values when adding a row', async () => {
    const { addRow } = await import('./assetTableService.js');
    (addRow as ReturnType<typeof vi.fn>).mockResolvedValue({
      id: 'row-1',
      displayNumber: 1,
      cellData: { name: 'Alice', age: null },
    });

    const { executeInternalTool, INTERNAL_TOOL_TABLE_ADD_ROW } = await import('./localAgentLoopService.js');
    await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_ADD_ROW,
      args: {
        resourceId: 'tasks',
        cellData: { name: 'Alice', age: 30, active: true, extra: { nested: true } },
      },
    });

    // age → '30', active → 'true', extra (object) → dropped
    expect(addRow).toHaveBeenCalledWith('u-1', 'tasks', {
      name: 'Alice',
      age: '30',
      active: 'true',
    });
  });

  it('exposes table_batch_add_rows in buildAgentTools', async () => {
    const { buildAgentTools } = await import('./localAgentLoopService.js');

    const tools = buildAgentTools('u-1');

    expect(tools.table_batch_add_rows).toBeDefined();
    expect(tools.table_batch_add_rows.parametersSchema).toMatchObject({
      type: 'object',
      required: ['resourceId', 'rows'],
      properties: {
        rows: {
          type: 'array',
          minItems: 2,
          maxItems: 10,
        },
      },
    });
  });

  it('dispatches table_batch_add_rows for a valid 2-row batch', async () => {
    const { batchAddRows } = await import('./assetTableService.js');
    (batchAddRows as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'row-1', displayNumber: 1, cellData: { name: 'Alice' } },
      { id: 'row-2', displayNumber: 2, cellData: { name: 'Bob' } },
    ]);

    const { executeInternalTool, INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS,
      args: {
        resourceId: 'tasks',
        rows: [{ cellData: { name: 'Alice' } }, { cellData: { name: 'Bob' } }],
      },
    });

    expect(result.ok).toBe(true);
    expect(batchAddRows).toHaveBeenCalledWith('u-1', 'tasks', [{ name: 'Alice' }, { name: 'Bob' }]);
  });

  it('rejects table_batch_add_rows when rows has fewer than 2 items', async () => {
    const { executeInternalTool, INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS,
      args: {
        resourceId: 'tasks',
        rows: [{ cellData: { name: 'Alice' } }],
      },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('rejects table_batch_add_rows when rows has more than 10 items', async () => {
    const { executeInternalTool, INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS } = await import('./localAgentLoopService.js');

    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS,
      args: {
        resourceId: 'tasks',
        rows: Array.from({ length: 11 }, (_, index) => ({ cellData: { name: `item-${index}` } })),
      },
    });

    expect(result.ok).toBe(false);
    expect(result.error?.code).toBe('invalid_args');
  });

  it('sanitizes each table_batch_add_rows row payload', async () => {
    const { batchAddRows } = await import('./assetTableService.js');
    (batchAddRows as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'row-1', displayNumber: 1, cellData: { name: 'Alice', age: '30', active: 'true' } },
      { id: 'row-2', displayNumber: 2, cellData: { name: 'Bob', score: '7', archived: null } },
    ]);

    const { executeInternalTool, INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS } = await import('./localAgentLoopService.js');
    await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS,
      args: {
        resourceId: 'tasks',
        rows: [
          {
            cellData: {
              name: 'Alice',
              age: 30,
              active: true,
              extra: { nested: true },
            },
          },
          {
            name: 'Bob',
            score: 7,
            archived: null,
            tags: ['x'],
          },
        ],
      },
    });

    expect(batchAddRows).toHaveBeenCalledWith('u-1', 'tasks', [
      { name: 'Alice', age: '30', active: 'true' },
      { name: 'Bob', score: '7', archived: null },
    ]);
  });

  // -------------------------------------------------------------------------
  // Highlight tool test
  // -------------------------------------------------------------------------

  it('dispatches highlight_list and returns highlights', async () => {
    const { listHighlights } = await import('./textHighlightService.js');
    (listHighlights as ReturnType<typeof vi.fn>).mockResolvedValue([
      { id: 'hl-1', selectedText: 'hello world', color: 'yellow' },
    ]);

    const { executeInternalTool, INTERNAL_TOOL_HIGHLIGHT_LIST } = await import('./localAgentLoopService.js');
    const result = await executeInternalTool({
      userId: 'u-1',
      toolName: INTERNAL_TOOL_HIGHLIGHT_LIST,
      args: {},
    });

    expect(result.ok).toBe(true);
    expect((result.data as { highlights: unknown[] }).highlights).toHaveLength(1);
  });
});
