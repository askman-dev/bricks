import {
  buildChatSessionId,
  type ChatRouter,
  CHAT_ROUTER_LOCAL,
  type ChatScopeType,
  normalizeChatThreadId,
  upsertChatScopeSetting,
  listChatScopeSettings,
} from './chatRouterService.js';
import { upsertChatChannelName, listChatChannelNames } from './chatChannelNameService.js';
import {
  listTodos,
  createTodo,
  updateTodo,
  completeTodo,
  deleteTodo,
} from './todoService.js';
import {
  listTables,
  createTable,
  getTable,
  addColumn,
  removeColumn,
  addRow,
  updateRow,
  deleteRow,
} from './assetTableService.js';
import { listHighlights } from './textHighlightService.js';
import type { AgentTool } from '../llm/types.js';

export const INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET = 'chat.channel.instruction.set';
export const INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET = 'chat.thread.instruction.set';
export const INTERNAL_TOOL_CHAT_CHANNEL_CREATE = 'chat.channel.create';
export const INTERNAL_TOOL_CHAT_THREAD_CREATE = 'chat.thread.create';
export const INTERNAL_TOOL_CHAT_CHANNEL_RENAME = 'chat.channel.rename';
export const INTERNAL_TOOL_CHAT_CHANNEL_LIST = 'chat.channel.list';
export const INTERNAL_TOOL_CHAT_CHANNEL_GET = 'chat.channel.get';
export const INTERNAL_TOOL_CHAT_THREAD_LIST = 'chat.thread.list';
export const INTERNAL_TOOL_CHAT_THREAD_GET = 'chat.thread.get';

// Todo tools
export const INTERNAL_TOOL_TODO_CREATE = 'todo.create';
export const INTERNAL_TOOL_TODO_LIST = 'todo.list';
export const INTERNAL_TOOL_TODO_COMPLETE = 'todo.complete';
export const INTERNAL_TOOL_TODO_UPDATE = 'todo.update';
export const INTERNAL_TOOL_TODO_DELETE = 'todo.delete';

// Asset table tools
export const INTERNAL_TOOL_TABLE_CREATE = 'table.create';
export const INTERNAL_TOOL_TABLE_LIST = 'table.list';
export const INTERNAL_TOOL_TABLE_GET = 'table.get';
export const INTERNAL_TOOL_TABLE_ADD_COLUMN = 'table.add_column';
export const INTERNAL_TOOL_TABLE_REMOVE_COLUMN = 'table.remove_column';
export const INTERNAL_TOOL_TABLE_ADD_ROW = 'table.add_row';
export const INTERNAL_TOOL_TABLE_UPDATE_ROW = 'table.update_row';
export const INTERNAL_TOOL_TABLE_DELETE_ROW = 'table.delete_row';

// Text highlight tools (highlight creation is manual via Flutter; list is AI-accessible)
export const INTERNAL_TOOL_HIGHLIGHT_LIST = 'highlight.list';

export const INTERNAL_TOOLS = [
  INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
  INTERNAL_TOOL_CHAT_THREAD_CREATE,
  INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
  INTERNAL_TOOL_CHAT_CHANNEL_LIST,
  INTERNAL_TOOL_CHAT_CHANNEL_GET,
  INTERNAL_TOOL_CHAT_THREAD_LIST,
  INTERNAL_TOOL_CHAT_THREAD_GET,
  INTERNAL_TOOL_TODO_CREATE,
  INTERNAL_TOOL_TODO_LIST,
  INTERNAL_TOOL_TODO_COMPLETE,
  INTERNAL_TOOL_TODO_UPDATE,
  INTERNAL_TOOL_TODO_DELETE,
  INTERNAL_TOOL_TABLE_CREATE,
  INTERNAL_TOOL_TABLE_LIST,
  INTERNAL_TOOL_TABLE_GET,
  INTERNAL_TOOL_TABLE_ADD_COLUMN,
  INTERNAL_TOOL_TABLE_REMOVE_COLUMN,
  INTERNAL_TOOL_TABLE_ADD_ROW,
  INTERNAL_TOOL_TABLE_UPDATE_ROW,
  INTERNAL_TOOL_TABLE_DELETE_ROW,
  INTERNAL_TOOL_HIGHLIGHT_LIST,
] as const;

export type InternalToolName = (typeof INTERNAL_TOOLS)[number];

export interface ExecuteInternalToolInput {
  userId: string;
  toolName: string;
  args: Record<string, unknown>;
}

export interface ExecuteInternalToolResult {
  ok: boolean;
  toolName: string;
  data: Record<string, unknown> | null;
  error:
    | {
        code: 'invalid_args' | 'not_implemented' | 'tool_not_allowed';
        message: string;
      }
    | null;
}

export interface InternalToolCall {
  toolName: string;
  args: Record<string, unknown>;
}

export interface ExecuteInternalToolSequenceResult {
  ok: boolean;
  calls: ExecuteInternalToolResult[];
  completedCalls: number;
  failedCall: ExecuteInternalToolResult | null;
}

export function inferInternalToolCallsFromMessage(input: {
  message: string;
  channelId: string;
  threadId?: string | null;
}): InternalToolCall[] {
  const text = input.message.trim();
  if (!text) return [];

  const lower = text.toLowerCase();
  const calls: InternalToolCall[] = [];

  if (lower.startsWith('/channel create ')) {
    const name = text.substring('/channel create '.length).trim();
    if (name) {
      calls.push({
        toolName: INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
        args: { channelId: name },
      });
    }
  }

  if (lower.startsWith('/thread create ')) {
    const name = text.substring('/thread create '.length).trim();
    if (name) {
      calls.push({
        toolName: INTERNAL_TOOL_CHAT_THREAD_CREATE,
        args: { channelId: input.channelId, threadId: name },
      });
    }
  }

  if (lower.startsWith('/channel instruction ')) {
    const instruction = text.substring('/channel instruction '.length).trim();
    if (instruction) {
      calls.push({
        toolName: INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
        args: { channelId: input.channelId, instruction },
      });
    }
  }

  if (lower.startsWith('/thread instruction ')) {
    const instruction = text.substring('/thread instruction '.length).trim();
    const effectiveThreadId = input.threadId ?? 'main';
    if (instruction && effectiveThreadId !== 'main') {
      calls.push({
        toolName: INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
        args: { channelId: input.channelId, threadId: effectiveThreadId, instruction },
      });
    }
  }

  return calls;
}

const MAX_IDENTIFIER_LENGTH = 255;

function readStringArg(args: Record<string, unknown>, key: string, maxLength?: number): string | null {
  const raw = args[key];
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed.length === 0) return null;
  if (maxLength !== undefined && trimmed.length > maxLength) return null;
  return trimmed;
}

async function persistInstruction(params: {
  userId: string;
  scopeType: ChatScopeType;
  channelId: string;
  threadId?: string | null;
  instructions: string;
}): Promise<ExecuteInternalToolResult> {
  const router: ChatRouter = CHAT_ROUTER_LOCAL;
  const setting = await upsertChatScopeSetting(params.userId, {
    scopeType: params.scopeType,
    channelId: params.channelId,
    threadId: params.threadId ?? null,
    router,
    instructions: params.instructions,
  });

  return {
    ok: true,
    toolName:
      params.scopeType === 'channel'
        ? INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET
        : INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
    data: {
      scopeType: setting.scopeType,
      channelId: setting.channelId,
      threadId: setting.threadId,
      instructions: setting.instructions,
      updatedAt: setting.updatedAt,
    },
    error: null,
  };
}

async function createChannelScope(params: {
  userId: string;
  channelId: string;
}): Promise<ExecuteInternalToolResult> {
  const router: ChatRouter = CHAT_ROUTER_LOCAL;
  await upsertChatScopeSetting(params.userId, {
    scopeType: 'channel',
    channelId: params.channelId,
    threadId: null,
    router,
    instructions: null,
  });

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
    data: {
      channelId: params.channelId,
      sessionId: buildChatSessionId(params.channelId, 'main'),
      scopeType: 'channel',
    },
    error: null,
  };
}

async function renameChannel(params: {
  userId: string;
  channelId: string;
  displayName: string;
}): Promise<ExecuteInternalToolResult> {
  const setting = await upsertChatChannelName(params.userId, {
    channelId: params.channelId,
    displayName: params.displayName,
  });

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
    data: {
      channelId: setting.channelId,
      displayName: setting.displayName,
      updatedAt: setting.updatedAt,
    },
    error: null,
  };
}

async function createThreadScope(params: {
  userId: string;
  channelId: string;
  threadId: string;
}): Promise<ExecuteInternalToolResult> {
  const router: ChatRouter = CHAT_ROUTER_LOCAL;
  const normalizedThreadId = normalizeChatThreadId(params.threadId);
  await upsertChatScopeSetting(params.userId, {
    scopeType: 'thread',
    channelId: params.channelId,
    threadId: normalizedThreadId,
    router,
    instructions: null,
  });

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_THREAD_CREATE,
    data: {
      channelId: params.channelId,
      threadId: normalizedThreadId,
      sessionId: buildChatSessionId(params.channelId, normalizedThreadId),
      scopeType: 'thread',
    },
    error: null,
  };
}

async function listChannels(params: {
  userId: string;
}): Promise<ExecuteInternalToolResult> {
  const [scopes, names] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannelNames(params.userId),
  ]);

  // Build the name map and collect unique channel IDs in one pass over `names`.
  const nameMap = new Map<string, string>();
  const channelIds = new Set<string>();
  for (const n of names) {
    nameMap.set(n.channelId, n.displayName);
    channelIds.add(n.channelId);
  }
  for (const s of scopes) channelIds.add(s.channelId);

  const channels = Array.from(channelIds)
    .sort()
    .map((channelId) => {
      const scope = scopes.find((s) => s.scopeType === 'channel' && s.channelId === channelId);
      const threadCount = scopes.filter((s) => s.scopeType === 'thread' && s.channelId === channelId).length;
      return {
        channelId,
        displayName: nameMap.get(channelId) ?? null,
        instructions: scope?.instructions ?? null,
        threadCount,
      };
    });

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_CHANNEL_LIST,
    data: { channels },
    error: null,
  };
}

async function getChannel(params: {
  userId: string;
  channelId: string;
}): Promise<ExecuteInternalToolResult> {
  const [scopes, names] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannelNames(params.userId),
  ]);

  const nameMap = new Map(names.map((n) => [n.channelId, n.displayName]));
  const channelScope = scopes.find(
    (s) => s.scopeType === 'channel' && s.channelId === params.channelId,
  );
  const threads = scopes
    .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId)
    .map((s) => ({ threadId: s.threadId, instructions: s.instructions }));

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_CHANNEL_GET,
    data: {
      channelId: params.channelId,
      displayName: nameMap.get(params.channelId) ?? null,
      instructions: channelScope?.instructions ?? null,
      threads,
    },
    error: null,
  };
}

async function listThreads(params: {
  userId: string;
  channelId: string;
}): Promise<ExecuteInternalToolResult> {
  const scopes = await listChatScopeSettings(params.userId);
  const threads = scopes
    .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId)
    .map((s) => ({ threadId: s.threadId, instructions: s.instructions }));

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_THREAD_LIST,
    data: { channelId: params.channelId, threads },
    error: null,
  };
}

async function getThread(params: {
  userId: string;
  channelId: string;
  threadId: string;
}): Promise<ExecuteInternalToolResult> {
  const [scopes, names] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannelNames(params.userId),
  ]);

  const nameMap = new Map(names.map((n) => [n.channelId, n.displayName]));
  const threadScope = scopes.find(
    (s) => s.scopeType === 'thread' && s.channelId === params.channelId && s.threadId === params.threadId,
  );
  const channelScope = scopes.find(
    (s) => s.scopeType === 'channel' && s.channelId === params.channelId,
  );

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_THREAD_GET,
    data: {
      channelId: params.channelId,
      threadId: params.threadId,
      instructions: threadScope?.instructions ?? null,
      parentChannel: {
        channelId: params.channelId,
        displayName: nameMap.get(params.channelId) ?? null,
        instructions: channelScope?.instructions ?? null,
      },
    },
    error: null,
  };
}

export async function executeInternalTool(
  input: ExecuteInternalToolInput,
): Promise<ExecuteInternalToolResult> {
  const { userId, toolName, args } = input;

  if (!INTERNAL_TOOLS.includes(toolName as InternalToolName)) {
    return {
      ok: false,
      toolName,
      data: null,
      error: {
        code: 'tool_not_allowed',
        message: `Tool is not in the internal allowlist: ${toolName}`,
      },
    };
  }

  switch (toolName as InternalToolName) {
    case INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const instruction = readStringArg(args, 'instruction');
      if (!channelId || !instruction) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and instruction are required string arguments',
          },
        };
      }
      return persistInstruction({
        userId,
        scopeType: 'channel',
        channelId,
        instructions: instruction,
      });
    }
    case INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH);
      const instruction = readStringArg(args, 'instruction');
      if (!channelId || !threadId || !instruction) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId, threadId, instruction are required string arguments',
          },
        };
      }
      if (threadId === 'main') {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message:
              "'main' is not a valid thread identifier for thread instructions; " +
              'use chat.channel.instruction.set to set channel-level instructions instead',
          },
        };
      }
      return persistInstruction({
        userId,
        scopeType: 'thread',
        channelId,
        threadId,
        instructions: instruction,
      });
    }
    case INTERNAL_TOOL_CHAT_CHANNEL_CREATE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH) ?? readStringArg(args, 'name', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId or name is required string argument',
          },
        };
      }
      return createChannelScope({ userId, channelId });
    }
    case INTERNAL_TOOL_CHAT_THREAD_CREATE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH) ?? readStringArg(args, 'name', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !threadId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and threadId (or name) are required string arguments',
          },
        };
      }
      return createThreadScope({ userId, channelId, threadId });
    }
    case INTERNAL_TOOL_CHAT_CHANNEL_RENAME: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const displayName = readStringArg(args, 'displayName', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !displayName) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and displayName are required string arguments',
          },
        };
      }
      return renameChannel({ userId, channelId, displayName });
    }
    case INTERNAL_TOOL_CHAT_CHANNEL_LIST: {
      return listChannels({ userId });
    }
    case INTERNAL_TOOL_CHAT_CHANNEL_GET: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId is a required string argument',
          },
        };
      }
      return getChannel({ userId, channelId });
    }
    case INTERNAL_TOOL_CHAT_THREAD_LIST: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId is a required string argument',
          },
        };
      }
      return listThreads({ userId, channelId });
    }
    case INTERNAL_TOOL_CHAT_THREAD_GET: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !threadId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and threadId are required string arguments',
          },
        };
      }
      return getThread({ userId, channelId, threadId });
    }

    // -------------------------------------------------------------------------
    // Todo tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_TODO_CREATE: {
      const title = readStringArg(args, 'title');
      const notes = typeof args.notes === 'string' ? args.notes.trim() || null : null;
      if (!title) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'title is a required string argument' },
        };
      }
      const todo = await createTodo(userId, { title, notes });
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST: {
      const includeCompleted = (args.includeCompleted ?? true) !== false;
      const todos = await listTodos(userId, { includeCompleted });
      return { ok: true, toolName, data: { todos }, error: null };
    }
    case INTERNAL_TOOL_TODO_COMPLETE: {
      const id = readStringArg(args, 'id');
      if (!id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'id is a required string argument' },
        };
      }
      const todo = await completeTodo(userId, id);
      if (!todo) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'Todo not found' } };
      }
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_UPDATE: {
      const id = readStringArg(args, 'id');
      if (!id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'id is a required string argument' },
        };
      }
      const update: Record<string, unknown> = {};
      if (typeof args.title === 'string') update.title = args.title;
      if (args.notes !== undefined) update.notes = typeof args.notes === 'string' ? args.notes : null;
      if (typeof args.isCompleted === 'boolean') update.isCompleted = args.isCompleted;
      const todo = await updateTodo(userId, id, update);
      if (!todo) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'Todo not found' } };
      }
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_DELETE: {
      const id = readStringArg(args, 'id');
      if (!id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'id is a required string argument' },
        };
      }
      const result = await deleteTodo(userId, id);
      return { ok: true, toolName, data: result, error: null };
    }

    // -------------------------------------------------------------------------
    // Asset table tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_TABLE_CREATE: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      const title = readStringArg(args, 'title');
      if (!resourceId || !title) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId and title are required string arguments' },
        };
      }
      const table = await createTable(userId, { resourceId, title });
      return { ok: true, toolName, data: table as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TABLE_LIST: {
      const tables = await listTables(userId);
      return { ok: true, toolName, data: { tables }, error: null };
    }
    case INTERNAL_TOOL_TABLE_GET: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      if (!resourceId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId is a required string argument' },
        };
      }
      const table = await getTable(userId, resourceId);
      if (!table) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'Table not found' } };
      }
      return { ok: true, toolName, data: table as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TABLE_ADD_COLUMN: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      const columnKey = readStringArg(args, 'columnKey', MAX_IDENTIFIER_LENGTH);
      const displayName = readStringArg(args, 'displayName');
      if (!resourceId || !columnKey || !displayName) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId, columnKey, and displayName are required' },
        };
      }
      const columnOrder = typeof args.columnOrder === 'number' ? Math.trunc(args.columnOrder) : 0;
      const col = await addColumn(userId, resourceId, { columnKey, displayName, columnOrder });
      return { ok: true, toolName, data: col as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TABLE_REMOVE_COLUMN: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      const columnKey = readStringArg(args, 'columnKey', MAX_IDENTIFIER_LENGTH);
      if (!resourceId || !columnKey) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId and columnKey are required' },
        };
      }
      const result = await removeColumn(userId, resourceId, columnKey);
      return { ok: true, toolName, data: result, error: null };
    }
    case INTERNAL_TOOL_TABLE_ADD_ROW: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      if (!resourceId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId is a required string argument' },
        };
      }
      const cellData: Record<string, string | null> =
        args.cellData && typeof args.cellData === 'object' && !Array.isArray(args.cellData)
          ? (args.cellData as Record<string, string | null>)
          : {};
      const row = await addRow(userId, resourceId, cellData);
      return { ok: true, toolName, data: row as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TABLE_UPDATE_ROW: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      const rowId = readStringArg(args, 'rowId');
      if (!resourceId || !rowId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId and rowId are required' },
        };
      }
      const cellData: Record<string, string | null> =
        args.cellData && typeof args.cellData === 'object' && !Array.isArray(args.cellData)
          ? (args.cellData as Record<string, string | null>)
          : {};
      const row = await updateRow(userId, resourceId, rowId, cellData);
      if (!row) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'Row not found' } };
      }
      return { ok: true, toolName, data: row as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TABLE_DELETE_ROW: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      const rowId = readStringArg(args, 'rowId');
      if (!resourceId || !rowId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId and rowId are required' },
        };
      }
      const result = await deleteRow(userId, resourceId, rowId);
      return { ok: true, toolName, data: result, error: null };
    }

    // -------------------------------------------------------------------------
    // Highlight tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_HIGHLIGHT_LIST: {
      const highlights = await listHighlights(userId);
      return { ok: true, toolName, data: { highlights }, error: null };
    }
  }
}

export async function executeInternalToolSequence(params: {
  userId: string;
  calls: InternalToolCall[];
  maxCalls?: number;
}): Promise<ExecuteInternalToolSequenceResult> {
  const limit = Math.max(1, Math.min(params.maxCalls ?? 4, 10));
  const boundedCalls = params.calls.slice(0, limit);
  const results: ExecuteInternalToolResult[] = [];

  for (const call of boundedCalls) {
    const result = await executeInternalTool({
      userId: params.userId,
      toolName: call.toolName,
      args: call.args,
    });
    results.push(result);
    if (!result.ok) {
      return {
        ok: false,
        calls: results,
        completedCalls: results.length - 1,
        failedCall: result,
      };
    }
  }

  return {
    ok: true,
    calls: results,
    completedCalls: results.length,
    failedCall: null,
  };
}

/**
 * Builds an AI-SDK-compatible tool set for the four P0 internal tools,
 * closing over `userId` so each tool can call `executeInternalTool` directly.
 *
 * The returned keys use underscores (e.g. `chat_channel_create`) because
 * OpenAI and Anthropic function-calling APIs do not allow dots in tool names.
 * The tool implementations delegate to `executeInternalTool` using the
 * canonical dot-delimited internal names.
 */
export function buildAgentTools(userId: string): Record<string, AgentTool> {
  const runTool = (toolName: string, args: Record<string, unknown>) =>
    executeInternalTool({ userId, toolName, args });

  return {
    chat_channel_instruction_set: {
      description:
        'Set or update the system instruction for a chat channel. ' +
        'Use this when the user asks to configure context or behaviour rules for a specific channel.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
          instruction: {
            type: 'string',
            description: 'The instruction text to apply to the channel.',
          },
        },
        required: ['channelId', 'instruction'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET, args),
    },

    chat_thread_instruction_set: {
      description:
        'Set or update the system instruction for a specific thread (sub-section) within a channel. ' +
        'Use this when the user asks to configure context or behaviour rules for a specific thread.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
          threadId: {
            type: 'string',
            description: 'The thread identifier.',
          },
          instruction: {
            type: 'string',
            description: 'The instruction text to apply to the thread.',
          },
        },
        required: ['channelId', 'threadId', 'instruction'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET, args),
    },

    chat_channel_create: {
      description:
        'Create a new chat channel. Use when the user requests a new channel by name.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The identifier for the new channel.',
          },
        },
        required: ['channelId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_CHANNEL_CREATE, args),
    },

    chat_thread_create: {
      description:
        'Create a new thread (sub-section) within an existing channel. ' +
        'Use when the user requests a new thread or sub-section.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
          threadId: {
            type: 'string',
            description: 'The identifier for the new thread.',
          },
        },
        required: ['channelId', 'threadId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_THREAD_CREATE, args),
    },

    chat_channel_rename: {
      description:
        'Rename a chat channel by setting its display name. ' +
        'Use this when the user asks to rename, retitle, or change the name of a channel.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
          displayName: {
            type: 'string',
            description: 'The new display name for the channel.',
          },
        },
        required: ['channelId', 'displayName'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_CHANNEL_RENAME, args),
    },

    chat_channel_list: {
      description:
        'List all chat channels available to the user, including their internal IDs, display names, ' +
        'instructions, and thread counts. Use this to discover channel IDs before calling other channel tools.',
      parametersSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_CHANNEL_LIST, args),
    },

    chat_channel_get: {
      description:
        'Get detailed information about a specific channel, including its display name, instructions, ' +
        'and the list of threads it contains.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
        },
        required: ['channelId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_CHANNEL_GET, args),
    },

    chat_thread_list: {
      description:
        'List all threads (sub-sections) within a given channel, including their IDs and instructions.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier whose threads to list.',
          },
        },
        required: ['channelId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_THREAD_LIST, args),
    },

    chat_thread_get: {
      description:
        'Get detailed information about a specific thread, including its instructions and its parent channel info.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel identifier.',
          },
          threadId: {
            type: 'string',
            description: 'The thread identifier.',
          },
        },
        required: ['channelId', 'threadId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_THREAD_GET, args),
    },

    // -------------------------------------------------------------------------
    // Todo tools
    // -------------------------------------------------------------------------
    todo_create: {
      description:
        'Create a new todo item for the user. Use when the user asks to add, create, or save a task or reminder.',
      parametersSchema: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'The todo title or task description.' },
          notes: { type: 'string', description: 'Optional additional notes.' },
        },
        required: ['title'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_CREATE, args),
    },

    todo_list: {
      description:
        'List the user\'s todo items. Use when the user asks to see, show, or query their todos or task list. ' +
        'Returns items as structured data; format them as a Markdown checklist in your reply.',
      parametersSchema: {
        type: 'object',
        properties: {
          includeCompleted: {
            type: 'boolean',
            description: 'Whether to include completed todos. Defaults to true.',
          },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST, args),
    },

    todo_complete: {
      description:
        'Mark a todo item as completed. Use when the user says they finished, completed, or checked off a task.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'The UUID of the todo item.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_COMPLETE, args),
    },

    todo_update: {
      description:
        'Update the title, notes, or completion status of an existing todo item.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'The UUID of the todo item to update.' },
          title: { type: 'string', description: 'New title.' },
          notes: { type: 'string', description: 'New notes.' },
          isCompleted: { type: 'boolean', description: 'New completion status.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_UPDATE, args),
    },

    todo_delete: {
      description:
        'Permanently delete a todo item. Use only when the user explicitly asks to remove or delete a specific task.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'The UUID of the todo item.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_DELETE, args),
    },

    // -------------------------------------------------------------------------
    // Asset table tools
    // -------------------------------------------------------------------------
    table_create: {
      description:
        'Create a new dynamic table resource. Use when the user asks to create a table, spreadsheet, or structured list.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: {
            type: 'string',
            description: 'A short stable identifier for the table (e.g. "tasks", "contacts"). Use lowercase-kebab.',
          },
          title: { type: 'string', description: 'Display title for the table.' },
        },
        required: ['resourceId', 'title'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_CREATE, args),
    },

    table_list: {
      description:
        'List all tables belonging to the user. Use to discover resourceIds before calling other table tools.',
      parametersSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_LIST, args),
    },

    table_get: {
      description:
        'Get the full content of a table: column definitions and all rows. ' +
        'Format the result as a Markdown table in your reply.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
        },
        required: ['resourceId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_GET, args),
    },

    table_add_column: {
      description:
        'Add a new column to a table. This is O(1) and does not modify existing rows. ' +
        'New cells for this column will default to null.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          columnKey: {
            type: 'string',
            description: 'A stable, unique key for the column (e.g. "status", "due_date"). Use lowercase-snake.',
          },
          displayName: { type: 'string', description: 'Human-readable column header.' },
          columnOrder: {
            type: 'number',
            description: 'Display order (lower = left). Defaults to 0.',
          },
        },
        required: ['resourceId', 'columnKey', 'displayName'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_ADD_COLUMN, args),
    },

    table_remove_column: {
      description:
        'Remove a column from a table schema. This is O(1); existing row data for this column ' +
        'is ignored (lazily orphaned) and will not be returned in future reads.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          columnKey: { type: 'string', description: 'The column key to remove.' },
        },
        required: ['resourceId', 'columnKey'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_REMOVE_COLUMN, args),
    },

    table_add_row: {
      description:
        'Add a new row to a table. Pass cell values as a cellData object whose keys are column keys.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          cellData: {
            type: 'object',
            description: 'Key-value pairs where keys are column keys and values are cell strings.',
            additionalProperties: { type: 'string' },
          },
        },
        required: ['resourceId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_ADD_ROW, args),
    },

    table_update_row: {
      description:
        'Update one or more cell values in an existing row. Only the supplied keys are changed; others are preserved.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          rowId: { type: 'string', description: 'The UUID of the row to update.' },
          cellData: {
            type: 'object',
            description: 'Key-value pairs of column keys and new cell values.',
            additionalProperties: { type: 'string' },
          },
        },
        required: ['resourceId', 'rowId', 'cellData'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_UPDATE_ROW, args),
    },

    table_delete_row: {
      description: 'Soft-delete a row from a table. The row will no longer appear in table_get results.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          rowId: { type: 'string', description: 'The UUID of the row to delete.' },
        },
        required: ['resourceId', 'rowId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_DELETE_ROW, args),
    },

    // -------------------------------------------------------------------------
    // Highlight tools
    // -------------------------------------------------------------------------
    highlight_list: {
      description:
        'List all text highlights the user has saved. Use when the user asks what they have highlighted, ' +
        'what they marked, or what annotations they have made.',
      parametersSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_HIGHLIGHT_LIST, args),
    },
  };
}
