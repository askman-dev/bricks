import {
  buildChatSessionId,
  type ChatRouter,
  CHAT_ROUTER_LOCAL,
  type ChatScopeType,
  normalizeChatThreadId,
  upsertChatScopeSetting,
  listChatScopeSettings,
} from './chatRouterService.js';
import { listChatChannels, upsertChatChannel } from './chatChannelService.js';
import {
  listTodos,
  createTodo,
  updateTodo,
  completeTodo,
  deleteTodo,
  type UpdateTodoInput,
} from './todoService.js';
import {
  listTodoLists,
  getTodoList,
  createTodoList,
  updateTodoList,
  deleteTodoList,
  type UpdateTodoListInput,
} from './todoListService.js';
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
} from './assetTableService.js';
import { sanitizeBatchRowCellData, sanitizeTableCellData } from './assetTableCellData.js';
import { listHighlights } from './textHighlightService.js';
import {
  listNotes,
  getNote,
  createNote,
  updateNote,
  deleteNote,
  readNoteLines,
  appendNoteLines,
  replaceNoteLines,
  deleteNoteLines,
} from './noteService.js';
import {
  listScheduledActions,
  getScheduledAction,
  createScheduledAction,
  updateScheduledAction,
  pauseScheduledAction,
  resumeScheduledAction,
  deleteScheduledAction,
  type CreateScheduledActionInput,
  type UpdateScheduledActionInput,
} from './scheduledActionService.js';
import {
  generateImageMedia,
  mediaGenerationJobToDto,
  startVideoGenerationJob,
  MediaGenerationError,
} from './mediaGenerationService.js';
import { mediaAssetToDto } from './mediaService.js';
import {
  buildChannelSite,
  channelSiteDto,
  channelSitePublishStatusDto,
  ChannelSiteError,
  copyMediaToSiteAssets,
  deleteWorkspacePath,
  ensureChannelSite,
  ensureWebsiteWorkspace,
  getChannelSitePublishStatus,
  listWorkspaceFiles,
  makeWorkspaceDirectory,
  readWorkspaceFile,
  runWorkspaceCommand,
  writeWorkspaceFile,
} from './channelSiteService.js';
import type { AgentTool } from '../llm/types.js';

export const INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET = 'chat.channel.instruction.set';
export const INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET = 'chat.thread.instruction.set';
export const INTERNAL_TOOL_CHAT_CHANNEL_CREATE = 'chat.channel.create';
export const INTERNAL_TOOL_CHAT_THREAD_CREATE = 'chat.thread.create';
export const INTERNAL_TOOL_CHAT_CHANNEL_RENAME = 'chat.channel.rename';
export const INTERNAL_TOOL_CHAT_THREAD_RENAME = 'chat.thread.rename';
export const INTERNAL_TOOL_CHAT_CHANNEL_LIST = 'chat.channel.list';
export const INTERNAL_TOOL_CHAT_CHANNEL_GET = 'chat.channel.get';
export const INTERNAL_TOOL_CHAT_THREAD_LIST = 'chat.thread.list';
export const INTERNAL_TOOL_CHAT_THREAD_GET = 'chat.thread.get';

// Media generation tools
export const INTERNAL_TOOL_MEDIA_IMAGE_GENERATE = 'media.image.generate';
export const INTERNAL_TOOL_MEDIA_VIDEO_GENERATE = 'media.video.generate';

// Channel website workspace tools
export const INTERNAL_TOOL_SITE_WORKSPACE_CONFIG = 'site.workspace.config';
export const INTERNAL_TOOL_SITE_WORKSPACE_INIT = 'site.workspace.init';
export const INTERNAL_TOOL_SITE_FILE_LIST = 'site.file.list';
export const INTERNAL_TOOL_SITE_FILE_READ = 'site.file.read';
export const INTERNAL_TOOL_SITE_FILE_WRITE = 'site.file.write';
export const INTERNAL_TOOL_SITE_DIRECTORY_MKDIR = 'site.directory.mkdir';
export const INTERNAL_TOOL_SITE_PATH_DELETE = 'site.path.delete';
export const INTERNAL_TOOL_SITE_SHELL_EXEC = 'site.shell.exec';
export const INTERNAL_TOOL_SITE_PUBLISH_STATUS = 'site.publish.status';
export const INTERNAL_TOOL_SITE_BUILD = 'site.build';
export const INTERNAL_TOOL_SITE_MEDIA_COPY = 'site.media.copy';

// Todo list tools (parent entities that group todo items)
export const INTERNAL_TOOL_TODO_LIST_CREATE = 'todolist.create';
export const INTERNAL_TOOL_TODO_LIST_LIST = 'todolist.list';
export const INTERNAL_TOOL_TODO_LIST_GET = 'todolist.get';
export const INTERNAL_TOOL_TODO_LIST_UPDATE = 'todolist.update';
export const INTERNAL_TOOL_TODO_LIST_DELETE = 'todolist.delete';

// Todo item tools (must reference a parent list id)
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
export const INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS = 'table.batch_add_rows';

// Text highlight tools (highlight creation is manual via Flutter; list is AI-accessible)
export const INTERNAL_TOOL_HIGHLIGHT_LIST = 'highlight.list';

// Note tools (long Markdown resources saved from chat)
export const INTERNAL_TOOL_NOTE_CREATE = 'note.create';
export const INTERNAL_TOOL_NOTE_LIST = 'note.list';
export const INTERNAL_TOOL_NOTE_GET = 'note.get';
export const INTERNAL_TOOL_NOTE_UPDATE = 'note.update';
export const INTERNAL_TOOL_NOTE_DELETE = 'note.delete';
export const INTERNAL_TOOL_NOTE_READ_LINES = 'note.read_lines';
export const INTERNAL_TOOL_NOTE_APPEND_LINES = 'note.append_lines';
export const INTERNAL_TOOL_NOTE_REPLACE_LINES = 'note.replace_lines';
export const INTERNAL_TOOL_NOTE_DELETE_LINES = 'note.delete_lines';

// Scheduled action tools
export const INTERNAL_TOOL_SCHEDULED_ACTION_CREATE = 'scheduled_action.create';
export const INTERNAL_TOOL_SCHEDULED_ACTION_LIST = 'scheduled_action.list';
export const INTERNAL_TOOL_SCHEDULED_ACTION_GET = 'scheduled_action.get';
export const INTERNAL_TOOL_SCHEDULED_ACTION_UPDATE = 'scheduled_action.update';
export const INTERNAL_TOOL_SCHEDULED_ACTION_PAUSE = 'scheduled_action.pause';
export const INTERNAL_TOOL_SCHEDULED_ACTION_RESUME = 'scheduled_action.resume';
export const INTERNAL_TOOL_SCHEDULED_ACTION_DELETE = 'scheduled_action.delete';

export const INTERNAL_TOOLS = [
  INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
  INTERNAL_TOOL_CHAT_THREAD_CREATE,
  INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
  INTERNAL_TOOL_CHAT_THREAD_RENAME,
  INTERNAL_TOOL_CHAT_CHANNEL_LIST,
  INTERNAL_TOOL_CHAT_CHANNEL_GET,
  INTERNAL_TOOL_CHAT_THREAD_LIST,
  INTERNAL_TOOL_CHAT_THREAD_GET,
  INTERNAL_TOOL_MEDIA_IMAGE_GENERATE,
  INTERNAL_TOOL_MEDIA_VIDEO_GENERATE,
  INTERNAL_TOOL_SITE_WORKSPACE_CONFIG,
  INTERNAL_TOOL_SITE_WORKSPACE_INIT,
  INTERNAL_TOOL_SITE_FILE_LIST,
  INTERNAL_TOOL_SITE_FILE_READ,
  INTERNAL_TOOL_SITE_FILE_WRITE,
  INTERNAL_TOOL_SITE_DIRECTORY_MKDIR,
  INTERNAL_TOOL_SITE_PATH_DELETE,
  INTERNAL_TOOL_SITE_SHELL_EXEC,
  INTERNAL_TOOL_SITE_PUBLISH_STATUS,
  INTERNAL_TOOL_SITE_BUILD,
  INTERNAL_TOOL_SITE_MEDIA_COPY,
  INTERNAL_TOOL_TODO_LIST_CREATE,
  INTERNAL_TOOL_TODO_LIST_LIST,
  INTERNAL_TOOL_TODO_LIST_GET,
  INTERNAL_TOOL_TODO_LIST_UPDATE,
  INTERNAL_TOOL_TODO_LIST_DELETE,
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
  INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS,
  INTERNAL_TOOL_HIGHLIGHT_LIST,
  INTERNAL_TOOL_NOTE_CREATE,
  INTERNAL_TOOL_NOTE_LIST,
  INTERNAL_TOOL_NOTE_GET,
  INTERNAL_TOOL_NOTE_UPDATE,
  INTERNAL_TOOL_NOTE_DELETE,
  INTERNAL_TOOL_NOTE_READ_LINES,
  INTERNAL_TOOL_NOTE_APPEND_LINES,
  INTERNAL_TOOL_NOTE_REPLACE_LINES,
  INTERNAL_TOOL_NOTE_DELETE_LINES,
  INTERNAL_TOOL_SCHEDULED_ACTION_CREATE,
  INTERNAL_TOOL_SCHEDULED_ACTION_LIST,
  INTERNAL_TOOL_SCHEDULED_ACTION_GET,
  INTERNAL_TOOL_SCHEDULED_ACTION_UPDATE,
  INTERNAL_TOOL_SCHEDULED_ACTION_PAUSE,
  INTERNAL_TOOL_SCHEDULED_ACTION_RESUME,
  INTERNAL_TOOL_SCHEDULED_ACTION_DELETE,
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
        code: 'invalid_args' | 'not_implemented' | 'tool_not_allowed' | 'not_found' | 'provider_error';
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

export interface AgentToolContext {
  channelId?: string | null;
  threadId?: string | null;
  defaultPrompt?: string | null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

function readBodyArg(args: Record<string, unknown>, key: string, maxLength = 1024 * 1024): string | null {
  const raw = args[key];
  if (typeof raw !== 'string') return null;
  if (raw.length > maxLength) return null;
  return raw;
}

function readLineArrayArg(args: Record<string, unknown>, key: string): string[] | null {
  const raw = args[key];
  if (!Array.isArray(raw) || raw.some((item) => typeof item !== 'string')) {
    return null;
  }
  return raw as string[];
}

function readPositiveIntegerArg(args: Record<string, unknown>, key: string): number | null {
  const raw = args[key];
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null;
  const value = Math.trunc(raw);
  return value > 0 ? value : null;
}

function invalidNoteMutation(toolName: string, error: unknown): ExecuteInternalToolResult {
  return {
    ok: false,
    toolName,
    data: null,
    error: {
      code: 'invalid_args',
      message: error instanceof Error ? error.message : 'Invalid note mutation',
    },
  };
}

function mediaGenerationFailure(toolName: string, error: unknown): ExecuteInternalToolResult {
  const message = error instanceof Error ? error.message : 'Media generation failed';
  const code =
    error instanceof MediaGenerationError && error.statusCode === 404
      ? 'not_found'
      : error instanceof MediaGenerationError && error.statusCode >= 500
        ? 'provider_error'
        : 'invalid_args';
  return {
    ok: false,
    toolName,
    data: null,
    error: { code, message },
  };
}

function channelSiteFailure(toolName: string, error: unknown): ExecuteInternalToolResult {
  const message = error instanceof Error ? error.message : 'Channel site operation failed';
  const code =
    error instanceof ChannelSiteError && error.statusCode === 404
      ? 'not_found'
      : 'invalid_args';
  return {
    ok: false,
    toolName,
    data: null,
    error: { code, message },
  };
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
  await Promise.all([
    upsertChatChannel(params.userId, {
      channelId: params.channelId,
      displayName: params.channelId,
      source: 'tool',
    }),
    upsertChatScopeSetting(params.userId, {
      scopeType: 'channel',
      channelId: params.channelId,
      threadId: null,
      router,
      instructions: null,
    }),
  ]);

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
  const setting = await upsertChatChannel(params.userId, {
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

async function renameThread(params: {
  userId: string;
  channelId: string;
  threadId: string;
  displayName: string;
}): Promise<ExecuteInternalToolResult> {
  const setting = await upsertChatChannel(params.userId, {
    channelId: params.channelId,
    threadId: params.threadId,
    displayName: params.displayName,
  });

  return {
    ok: true,
    toolName: INTERNAL_TOOL_CHAT_THREAD_RENAME,
    data: {
      channelId: setting.channelId,
      threadId: setting.threadId,
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
  await Promise.all([
    upsertChatChannel(params.userId, {
      channelId: params.channelId,
      threadId: normalizedThreadId,
      displayName: normalizedThreadId,
      source: 'tool',
    }),
    upsertChatScopeSetting(params.userId, {
      scopeType: 'thread',
      channelId: params.channelId,
      threadId: normalizedThreadId,
      router,
      instructions: null,
    }),
  ]);

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
  const [scopes, registryRows] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannels(params.userId),
  ]);

  const nameMap = new Map<string, string>();
  const channelIds = new Set<string>();
  for (const channel of registryRows) {
    if (channel.scopeType !== 'channel') continue;
    nameMap.set(channel.channelId, channel.displayName);
    channelIds.add(channel.channelId);
  }

  const channels = Array.from(channelIds)
    .sort()
    .map((channelId) => {
      const scope = scopes.find((s) => s.scopeType === 'channel' && s.channelId === channelId);
      const threadCount = registryRows.filter(
        (row) => row.scopeType === 'thread' && row.channelId === channelId,
      ).length;
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
  const [scopes, channels] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannels(params.userId),
  ]);

  const nameMap = new Map(
    channels
      .filter((n) => n.scopeType === 'channel')
      .map((n) => [n.channelId, n.displayName]),
  );
  const channelScope = scopes.find(
    (s) => s.scopeType === 'channel' && s.channelId === params.channelId,
  );
  const instructionsByThreadId = new Map(
    scopes
      .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId && s.threadId)
      .map((s) => [s.threadId as string, s.instructions]),
  );
  const threads = channels
    .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId && s.threadId)
    .map((s) => ({
      threadId: s.threadId,
      displayName: s.displayName,
      instructions: s.threadId ? (instructionsByThreadId.get(s.threadId) ?? null) : null,
    }));

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
  const [scopes, channels] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannels(params.userId),
  ]);

  const instructionsByThreadId = new Map(
    scopes
      .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId && s.threadId)
      .map((s) => [s.threadId as string, s.instructions]),
  );
  const threads = channels
    .filter((s) => s.scopeType === 'thread' && s.channelId === params.channelId && s.threadId)
    .map((s) => ({
      threadId: s.threadId,
      displayName: s.displayName,
      instructions: s.threadId ? (instructionsByThreadId.get(s.threadId) ?? null) : null,
    }));

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
  const [scopes, channels] = await Promise.all([
    listChatScopeSettings(params.userId),
    listChatChannels(params.userId),
  ]);

  const nameMap = new Map(
    channels
      .filter((n) => n.scopeType === 'channel')
      .map((n) => [n.channelId, n.displayName]),
  );
  const threadNameMap = new Map(
    channels
      .filter((n) => n.scopeType === 'thread' && n.threadId)
      .map((n) => [`${n.channelId}:${n.threadId}`, n.displayName]),
  );
  const threadDisplayName = threadNameMap.get(`${params.channelId}:${params.threadId}`) ?? null;
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
      displayName: threadDisplayName,
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
    case INTERNAL_TOOL_CHAT_THREAD_RENAME: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH);
      const displayName = readStringArg(args, 'displayName', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !threadId || !displayName) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId, threadId, and displayName are required string arguments',
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
            message: 'threadId must reference a thread, not the channel scope',
          },
        };
      }
      return renameThread({ userId, channelId, threadId, displayName });
    }
    case INTERNAL_TOOL_MEDIA_IMAGE_GENERATE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH);
      const prompt = readStringArg(args, 'prompt');
      const referenceMediaIds = readLineArrayArg(args, 'referenceMediaIds') ?? [];
      const model = readStringArg(args, 'model', MAX_IDENTIFIER_LENGTH);
      const configId = readStringArg(args, 'configId', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !prompt) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and prompt are required string arguments',
          },
        };
      }
      try {
        const { job, media } = await generateImageMedia({
          userId,
          channelId,
          threadId,
          prompt,
          referenceMediaIds,
          model,
          configId,
        });
        return {
          ok: true,
          toolName,
          data: {
            job: mediaGenerationJobToDto(job, media),
            media: mediaAssetToDto(media),
          },
          error: null,
        };
      } catch (error) {
        return mediaGenerationFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_MEDIA_VIDEO_GENERATE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const threadId = readStringArg(args, 'threadId', MAX_IDENTIFIER_LENGTH);
      const prompt = readStringArg(args, 'prompt');
      const referenceMediaIds = readLineArrayArg(args, 'referenceMediaIds') ?? [];
      const firstFrameMediaId = readStringArg(args, 'firstFrameMediaId', MAX_IDENTIFIER_LENGTH);
      const lastFrameMediaId = readStringArg(args, 'lastFrameMediaId', MAX_IDENTIFIER_LENGTH);
      const aspectRatio = readStringArg(args, 'aspectRatio', MAX_IDENTIFIER_LENGTH);
      const durationSeconds = readPositiveIntegerArg(args, 'durationSeconds');
      const resolution = readStringArg(args, 'resolution', MAX_IDENTIFIER_LENGTH);
      const model = readStringArg(args, 'model', MAX_IDENTIFIER_LENGTH);
      const configId = readStringArg(args, 'configId', MAX_IDENTIFIER_LENGTH);
      if (!channelId || !prompt) {
        return {
          ok: false,
          toolName,
          data: null,
          error: {
            code: 'invalid_args',
            message: 'channelId and prompt are required string arguments',
          },
        };
      }
      try {
        const job = await startVideoGenerationJob({
          userId,
          channelId,
          threadId,
          prompt,
          referenceMediaIds,
          firstFrameMediaId,
          lastFrameMediaId,
          aspectRatio,
          durationSeconds,
          resolution,
          model,
          configId,
        });
        return {
          ok: true,
          toolName,
          data: {
            job: mediaGenerationJobToDto(job),
          },
          error: null,
        };
      } catch (error) {
        return mediaGenerationFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_WORKSPACE_CONFIG: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId is a required string argument' },
        };
      }
      try {
        const site = await ensureChannelSite(userId, channelId);
        return { ok: true, toolName, data: { site: channelSiteDto(site) }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_WORKSPACE_INIT: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId is a required string argument' },
        };
      }
      try {
        const site = await ensureWebsiteWorkspace(userId, channelId);
        return { ok: true, toolName, data: { site: channelSiteDto(site) }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_FILE_LIST: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const relativePath = readStringArg(args, 'path');
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId is a required string argument' },
        };
      }
      try {
        const files = await listWorkspaceFiles({ userId, channelId, relativePath: relativePath ?? undefined });
        return { ok: true, toolName, data: { files }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_FILE_READ: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const relativePath = readStringArg(args, 'path');
      if (!channelId || !relativePath) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId and path are required string arguments' },
        };
      }
      try {
        const file = await readWorkspaceFile({ userId, channelId, relativePath });
        return { ok: true, toolName, data: { file }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_FILE_WRITE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const relativePath = readStringArg(args, 'path');
      const content = readBodyArg(args, 'content');
      if (!channelId || !relativePath || content == null) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId, path, and content are required' },
        };
      }
      try {
        const file = await writeWorkspaceFile({ userId, channelId, relativePath, content });
        return { ok: true, toolName, data: { file }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_DIRECTORY_MKDIR: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const relativePath = readStringArg(args, 'path');
      if (!channelId || !relativePath) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId and path are required string arguments' },
        };
      }
      try {
        const directory = await makeWorkspaceDirectory({ userId, channelId, relativePath });
        return { ok: true, toolName, data: { directory }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_PATH_DELETE: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const relativePath = readStringArg(args, 'path');
      if (!channelId || !relativePath) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId and path are required string arguments' },
        };
      }
      try {
        const result = await deleteWorkspacePath({ userId, channelId, relativePath });
        return { ok: true, toolName, data: result, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_SHELL_EXEC: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const command = readStringArg(args, 'command');
      if (!channelId || !command) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId and command are required string arguments' },
        };
      }
      try {
        const result = await runWorkspaceCommand({ userId, channelId, command });
        return { ok: result.exitCode === 0, toolName, data: result, error: result.exitCode === 0 ? null : { code: 'invalid_args', message: 'Workspace command failed' } };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_PUBLISH_STATUS: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId is a required string argument' },
        };
      }
      try {
        const result = await getChannelSitePublishStatus({ userId, channelId });
        return {
          ok: true,
          toolName,
          data: channelSitePublishStatusDto(result.site, result.status),
          error: null,
        };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_BUILD: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      if (!channelId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId is a required string argument' },
        };
      }
      try {
        const result = await buildChannelSite({ userId, channelId });
        return {
          ok: result.ok,
          toolName,
          data: { site: channelSiteDto(result.site), log: result.log },
          error: result.ok ? null : { code: 'invalid_args', message: 'Site build failed; inspect jobs/build.log' },
        };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    case INTERNAL_TOOL_SITE_MEDIA_COPY: {
      const channelId = readStringArg(args, 'channelId', MAX_IDENTIFIER_LENGTH);
      const mediaId = readStringArg(args, 'mediaId', MAX_IDENTIFIER_LENGTH);
      const filename = readStringArg(args, 'filename');
      if (!channelId || !mediaId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId and mediaId are required string arguments' },
        };
      }
      try {
        const copied = await copyMediaToSiteAssets({ userId, channelId, mediaId, filename });
        return { ok: true, toolName, data: { asset: copied }, error: null };
      } catch (error) {
        return channelSiteFailure(toolName, error);
      }
    }
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_TODO_LIST_CREATE: {
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
      const list = await createTodoList(userId, { title, notes });
      return { ok: true, toolName, data: list as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST_LIST: {
      const lists = await listTodoLists(userId);
      return { ok: true, toolName, data: { lists }, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST_GET: {
      const listId = readStringArg(args, 'listId');
      if (!listId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId is a required string argument' },
        };
      }
      const list = await getTodoList(userId, listId);
      if (!list) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Todo list not found' } };
      }
      return { ok: true, toolName, data: list as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST_UPDATE: {
      const listId = readStringArg(args, 'listId');
      if (!listId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId is a required string argument' },
        };
      }
      const update: UpdateTodoListInput = {};
      if (typeof args.title === 'string') update.title = args.title;
      if (args.notes !== undefined) update.notes = typeof args.notes === 'string' ? args.notes : null;
      const list = await updateTodoList(userId, listId, update);
      if (!list) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Todo list not found' } };
      }
      return { ok: true, toolName, data: list as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST_DELETE: {
      const listId = readStringArg(args, 'listId');
      if (!listId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId is a required string argument' },
        };
      }
      const result = await deleteTodoList(userId, listId);
      return { ok: true, toolName, data: result, error: null };
    }

    // -------------------------------------------------------------------------
    // Todo item tools (each item must belong to a parent todo list)
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_TODO_CREATE: {
      const listId = readStringArg(args, 'listId');
      const title = readStringArg(args, 'title');
      const notes = typeof args.notes === 'string' ? args.notes.trim() || null : null;
      if (!listId || !title) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId and title are required string arguments' },
        };
      }
      const todo = await createTodo(userId, listId, { title, notes });
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_LIST: {
      const listId = readStringArg(args, 'listId');
      if (!listId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId is a required string argument' },
        };
      }
      const includeCompleted = (args.includeCompleted ?? true) !== false;
      const todos = await listTodos(userId, listId, { includeCompleted });
      return { ok: true, toolName, data: { todos }, error: null };
    }
    case INTERNAL_TOOL_TODO_COMPLETE: {
      const listId = readStringArg(args, 'listId');
      const id = readStringArg(args, 'id');
      if (!listId || !id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId and id are required string arguments' },
        };
      }
      const todo = await completeTodo(userId, listId, id);
      if (!todo) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Todo not found' } };
      }
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_UPDATE: {
      const listId = readStringArg(args, 'listId');
      const id = readStringArg(args, 'id');
      if (!listId || !id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId and id are required string arguments' },
        };
      }
      const update: UpdateTodoInput = {};
      if (typeof args.title === 'string') update.title = args.title;
      if (args.notes !== undefined) update.notes = typeof args.notes === 'string' ? args.notes : null;
      if (typeof args.isCompleted === 'boolean') update.isCompleted = args.isCompleted;
      const todo = await updateTodo(userId, listId, id, update);
      if (!todo) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Todo not found' } };
      }
      return { ok: true, toolName, data: todo as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_TODO_DELETE: {
      const listId = readStringArg(args, 'listId');
      const id = readStringArg(args, 'id');
      if (!listId || !id) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'listId and id are required string arguments' },
        };
      }
      const result = await deleteTodo(userId, listId, id);
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
      const cellData = sanitizeTableCellData(args.cellData);
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
      const cellData = sanitizeTableCellData(args.cellData);
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
    case INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS: {
      const resourceId = readStringArg(args, 'resourceId', MAX_IDENTIFIER_LENGTH);
      if (!resourceId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'resourceId is a required string argument' },
        };
      }
      if (!Array.isArray(args.rows) || args.rows.length < 2 || args.rows.length > 10) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'rows must be an array with 2 to 10 items' },
        };
      }
      const cellDataArray = (args.rows as unknown[]).map((item) => sanitizeBatchRowCellData(item));
      const rows = await batchAddRows(userId, resourceId, cellDataArray);
      return { ok: true, toolName, data: { rows } as unknown as Record<string, unknown>, error: null };
    }

    // -------------------------------------------------------------------------
    // Highlight tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_HIGHLIGHT_LIST: {
      const highlights = await listHighlights(userId);
      return { ok: true, toolName, data: { highlights }, error: null };
    }

    // -------------------------------------------------------------------------
    // Note tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_NOTE_CREATE: {
      const title = readStringArg(args, 'title');
      const body = readBodyArg(args, 'body') ?? '';
      if (!title) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'title is a required string argument' },
        };
      }
      try {
        const note = await createNote(userId, {
          title,
          body,
          isPublished: typeof args.isPublished === 'boolean' ? args.isPublished : true,
        });
        return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
      } catch (error) {
        return invalidNoteMutation(toolName, error);
      }
    }
    case INTERNAL_TOOL_NOTE_LIST: {
      const notes = await listNotes(userId, {
        includeUnpublished: args.includeUnpublished === true,
      });
      return { ok: true, toolName, data: { notes }, error: null };
    }
    case INTERNAL_TOOL_NOTE_GET: {
      const noteId = readStringArg(args, 'noteId');
      if (!noteId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId is a required string argument' },
        };
      }
      const note = await getNote(userId, noteId);
      if (!note) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
      }
      return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_NOTE_UPDATE: {
      const noteId = readStringArg(args, 'noteId');
      if (!noteId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId is a required string argument' },
        };
      }
      const input: { title?: string; body?: string; isPublished?: boolean } = {};
      if (typeof args.title === 'string') input.title = args.title;
      if (typeof args.body === 'string') input.body = args.body;
      if (typeof args.isPublished === 'boolean') input.isPublished = args.isPublished;
      try {
        const note = await updateNote(userId, noteId, input);
        if (!note) {
          return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
        }
        return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
      } catch (error) {
        return invalidNoteMutation(toolName, error);
      }
    }
    case INTERNAL_TOOL_NOTE_DELETE: {
      const noteId = readStringArg(args, 'noteId');
      if (!noteId) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId is a required string argument' },
        };
      }
      const result = await deleteNote(userId, noteId);
      return { ok: true, toolName, data: result, error: null };
    }
    case INTERNAL_TOOL_NOTE_READ_LINES: {
      const noteId = readStringArg(args, 'noteId');
      const startLine = readPositiveIntegerArg(args, 'startLine') ?? 1;
      const endLine = args.endLine === undefined ? undefined : readPositiveIntegerArg(args, 'endLine');
      if (!noteId || (args.endLine !== undefined && !endLine)) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId, startLine, and endLine must be valid' },
        };
      }
      const result = await readNoteLines(userId, noteId, startLine, endLine ?? undefined);
      if (!result) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
      }
      return { ok: true, toolName, data: result as unknown as Record<string, unknown>, error: null };
    }
    case INTERNAL_TOOL_NOTE_APPEND_LINES: {
      const noteId = readStringArg(args, 'noteId');
      const lines = readLineArrayArg(args, 'lines');
      if (!noteId || !lines) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId and lines are required' },
        };
      }
      try {
        const note = await appendNoteLines(userId, noteId, lines);
        if (!note) {
          return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
        }
        return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
      } catch (error) {
        return invalidNoteMutation(toolName, error);
      }
    }
    case INTERNAL_TOOL_NOTE_REPLACE_LINES: {
      const noteId = readStringArg(args, 'noteId');
      const startLine = readPositiveIntegerArg(args, 'startLine');
      const endLine = readPositiveIntegerArg(args, 'endLine');
      const lines = readLineArrayArg(args, 'lines');
      if (!noteId || !startLine || !endLine || !lines) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId, startLine, endLine, and lines are required' },
        };
      }
      try {
        const note = await replaceNoteLines(userId, noteId, startLine, endLine, lines);
        if (!note) {
          return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
        }
        return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
      } catch (error) {
        return invalidNoteMutation(toolName, error);
      }
    }
    case INTERNAL_TOOL_NOTE_DELETE_LINES: {
      const noteId = readStringArg(args, 'noteId');
      const startLine = readPositiveIntegerArg(args, 'startLine');
      const endLine = readPositiveIntegerArg(args, 'endLine');
      if (!noteId || !startLine || !endLine) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'noteId, startLine, and endLine are required' },
        };
      }
      try {
        const note = await deleteNoteLines(userId, noteId, startLine, endLine);
        if (!note) {
          return { ok: false, toolName, data: null, error: { code: 'not_found', message: 'Note not found' } };
        }
        return { ok: true, toolName, data: note as unknown as Record<string, unknown>, error: null };
      } catch (error) {
        return invalidNoteMutation(toolName, error);
      }
    }

    // -------------------------------------------------------------------------
    // Scheduled action tools
    // -------------------------------------------------------------------------
    case INTERNAL_TOOL_SCHEDULED_ACTION_CREATE: {
      const channelId = args.channelId as string | undefined;
      const title = args.title as string | undefined;
      const prompt = args.prompt as string | undefined;
      const scheduleExpr = args.scheduleExpr as string | undefined;
      const intervalSeconds = args.intervalSeconds as number | undefined;
      if (!channelId || !title || !prompt || !scheduleExpr || intervalSeconds == null) {
        return {
          ok: false,
          toolName,
          data: null,
          error: { code: 'invalid_args', message: 'channelId, title, prompt, scheduleExpr and intervalSeconds are required' },
        };
      }
      const input: CreateScheduledActionInput = {
        channelId,
        threadId: args.threadId as string | null | undefined,
        title,
        prompt,
        scheduleExpr,
        intervalSeconds: Number(intervalSeconds),
        timezone: (args.timezone as string | undefined) ?? 'UTC',
      };
      const action = await createScheduledAction(userId, input);
      return { ok: true, toolName, data: { action }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_LIST: {
      const actions = await listScheduledActions(userId);
      return { ok: true, toolName, data: { actions }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_GET: {
      const id = args.id as string | undefined;
      if (!id) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'id is required' } };
      }
      const action = await getScheduledAction(userId, id);
      if (!action) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: `Scheduled action ${id} not found` } };
      }
      return { ok: true, toolName, data: { action }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_UPDATE: {
      const id = args.id as string | undefined;
      if (!id) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'id is required' } };
      }
      const input: UpdateScheduledActionInput = {
        title: args.title as string | undefined,
        prompt: args.prompt as string | undefined,
        scheduleExpr: args.scheduleExpr as string | undefined,
        intervalSeconds: args.intervalSeconds != null ? Number(args.intervalSeconds) : undefined,
        timezone: args.timezone as string | undefined,
      };
      const action = await updateScheduledAction(userId, id, input);
      if (!action) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: `Scheduled action ${id} not found` } };
      }
      return { ok: true, toolName, data: { action }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_PAUSE: {
      const id = args.id as string | undefined;
      if (!id) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'id is required' } };
      }
      const action = await pauseScheduledAction(userId, id);
      if (!action) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: `Scheduled action ${id} not found or not active` } };
      }
      return { ok: true, toolName, data: { action }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_RESUME: {
      const id = args.id as string | undefined;
      if (!id) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'id is required' } };
      }
      const action = await resumeScheduledAction(userId, id);
      if (!action) {
        return { ok: false, toolName, data: null, error: { code: 'not_found', message: `Scheduled action ${id} not found or not paused` } };
      }
      return { ok: true, toolName, data: { action }, error: null };
    }

    case INTERNAL_TOOL_SCHEDULED_ACTION_DELETE: {
      const id = args.id as string | undefined;
      if (!id) {
        return { ok: false, toolName, data: null, error: { code: 'invalid_args', message: 'id is required' } };
      }
      const result = await deleteScheduledAction(userId, id);
      return { ok: true, toolName, data: result, error: null };
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
export function buildAgentTools(
  userId: string,
  context: AgentToolContext = {},
): Record<string, AgentTool> {
  const runTool = (toolName: string, args: Record<string, unknown>) => {
    const effectiveArgs = { ...args };
    if (
      toolName === INTERNAL_TOOL_MEDIA_IMAGE_GENERATE ||
      toolName === INTERNAL_TOOL_MEDIA_VIDEO_GENERATE ||
      toolName.startsWith('site.')
    ) {
      if (typeof effectiveArgs.channelId !== 'string' && context.channelId) {
        effectiveArgs.channelId = context.channelId;
      }
      if (typeof effectiveArgs.threadId !== 'string' && context.threadId) {
        effectiveArgs.threadId = context.threadId;
      }
      if (typeof effectiveArgs.prompt !== 'string' && context.defaultPrompt) {
        effectiveArgs.prompt = context.defaultPrompt;
      }
    }
    return executeInternalTool({ userId, toolName, args: effectiveArgs });
  };

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
        'Get detailed information about a specific thread, including its display name, instructions and its parent channel info.',
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

    chat_thread_rename: {
      description:
        'Rename a thread by setting its display name. ' +
        'Use this when the user asks to rename, retitle, or change the name of a thread.',
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
          displayName: {
            type: 'string',
            description: 'The new display name for the thread.',
          },
        },
        required: ['channelId', 'threadId', 'displayName'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_CHAT_THREAD_RENAME, args),
    },

    media_image_generate: {
      description:
        'Generate a durable image attachment in a Bricks channel using Gemini image generation. ' +
        'Use when the user explicitly asks to create or edit an image. For image editing, pass uploaded image media IDs as referenceMediaIds.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel where the generated image should be stored.',
          },
          threadId: {
            type: 'string',
            description: 'Optional thread identifier for the generated media.',
          },
          prompt: {
            type: 'string',
            description: 'The image generation or editing prompt.',
          },
          referenceMediaIds: {
            type: 'array',
            description: 'Optional image media IDs to use as references for image editing.',
            items: { type: 'string' },
          },
        },
        required: ['prompt'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_MEDIA_IMAGE_GENERATE, args),
    },

    media_video_generate: {
      description:
        'Start a durable Veo video generation job in a Bricks channel. ' +
        'Use referenceMediaIds for up to three style/content reference images, or firstFrameMediaId and optional lastFrameMediaId for interpolation.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: {
            type: 'string',
            description: 'The channel where the generated video should be stored.',
          },
          threadId: {
            type: 'string',
            description: 'Optional thread identifier for the video job.',
          },
          prompt: {
            type: 'string',
            description: 'The video generation prompt, including motion, camera, style, and audio cues where needed.',
          },
          referenceMediaIds: {
            type: 'array',
            description: 'Optional image media IDs used as Veo referenceImages; maximum three.',
            items: { type: 'string' },
            maxItems: 3,
          },
          firstFrameMediaId: {
            type: 'string',
            description: 'Optional image media ID to use as the starting frame.',
          },
          lastFrameMediaId: {
            type: 'string',
            description: 'Optional image media ID to use as the ending frame; requires firstFrameMediaId.',
          },
          aspectRatio: {
            type: 'string',
            enum: ['16:9', '9:16'],
            description: 'Optional Veo aspect ratio.',
          },
          durationSeconds: {
            type: 'number',
            enum: [4, 6, 8],
            description: 'Optional Veo duration. Use 8 when using reference images or 1080p/4k.',
          },
          resolution: {
            type: 'string',
            enum: ['720p', '1080p', '4k'],
            description: 'Optional Veo output resolution.',
          },
        },
        required: ['prompt'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_MEDIA_VIDEO_GENERATE, args),
    },

    site_workspace_config: {
      description:
        'Return the current channel website workspace configuration, including public URL, build log path, and dist path. Use before creating or editing a website.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_WORKSPACE_CONFIG, args),
    },

    site_workspace_init: {
      description:
        'Initialize the current channel static React/Vite/TypeScript website workspace and starter git repository.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_WORKSPACE_INIT, args),
    },

    site_file_list: {
      description: 'List files inside the current channel website workspace.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          path: { type: 'string', description: 'Optional workspace-relative directory path.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_FILE_LIST, args),
    },

    site_file_read: {
      description: 'Read a UTF-8 text file from the current channel website workspace.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          path: { type: 'string', description: 'Workspace-relative file path.' },
        },
        required: ['path'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_FILE_READ, args),
    },

    site_file_write: {
      description: 'Create or replace a UTF-8 text file in the current channel website workspace.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          path: { type: 'string', description: 'Workspace-relative file path.' },
          content: { type: 'string', description: 'Full file contents.' },
        },
        required: ['path', 'content'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_FILE_WRITE, args),
    },

    site_directory_mkdir: {
      description: 'Create a directory inside the current channel website workspace.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          path: { type: 'string', description: 'Workspace-relative directory path.' },
        },
        required: ['path'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_DIRECTORY_MKDIR, args),
    },

    site_path_delete: {
      description: 'Delete a file or directory inside the current channel website workspace, excluding protected paths.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          path: { type: 'string', description: 'Workspace-relative file or directory path.' },
        },
        required: ['path'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_PATH_DELETE, args),
    },

    site_shell_exec: {
      description:
        'Run a shell command inside the current channel website workspace. Use for npm, git, and local build/debug commands after editing source files.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          command: { type: 'string', description: 'Shell command to run inside the workspace.' },
        },
        required: ['command'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_SHELL_EXEC, args),
    },

    site_publish_status: {
      description:
        'Return the current channel website publish status, public URL, latest publish time, current git commit, and last successful published commit. Use before reporting whether a site is live or up to date.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_PUBLISH_STATUS, args),
    },

    site_build: {
      description:
        'Publish the current channel website: create a git snapshot commit, install dependencies if needed, build the site, and publish the latest successful dist to the fixed public URL. After editing website files, call this tool automatically so the user does not need to ask for compilation. Failed builds keep the previous public dist.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_BUILD, args),
    },

    site_media_copy: {
      description:
        'Copy an uploaded or generated channel media asset into the website public/assets directory so React code can reference it.',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel identifier. Defaults to the current chat channel.' },
          mediaId: { type: 'string', description: 'Media asset ID from the current channel.' },
          filename: { type: 'string', description: 'Optional destination filename suffix.' },
        },
        required: ['mediaId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SITE_MEDIA_COPY, args),
    },

    // -------------------------------------------------------------------------
    // Todo list tools (parent entities that group todo items by topic)
    // -------------------------------------------------------------------------
    todolist_create: {
      description:
        'Create a new todo list (a named group for todo items). Use when the user wants to create a todo list, project, or task group. ' +
        'After creating the list, use todo_create to add items to it.',
      parametersSchema: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Name of the todo list (e.g. "Work tasks", "Shopping").' },
          notes: { type: 'string', description: 'Optional description for the list.' },
        },
        required: ['title'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST_CREATE, args),
    },

    todolist_list: {
      description:
        'List all the user\'s todo lists. Use when the user asks to see their lists or before operating on a specific list.',
      parametersSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST_LIST, args),
    },

    todolist_get: {
      description:
        'Get a specific todo list with all its items. Use when the user asks to view a particular list and its tasks.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the todo list.' },
        },
        required: ['listId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST_GET, args),
    },

    todolist_update: {
      description: 'Update the title or notes of an existing todo list.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the todo list to update.' },
          title: { type: 'string', description: 'New title.' },
          notes: { type: 'string', description: 'New notes.' },
        },
        required: ['listId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST_UPDATE, args),
    },

    todolist_delete: {
      description:
        'Permanently delete a todo list and all its items. Use only when the user explicitly asks to remove an entire list.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the todo list to delete.' },
        },
        required: ['listId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST_DELETE, args),
    },

    // -------------------------------------------------------------------------
    // Todo item tools (each item must belong to a parent todo list)
    // -------------------------------------------------------------------------
    todo_create: {
      description:
        'Create a new todo item inside a specific todo list. You must specify the listId of the parent list. ' +
        'If no list exists yet, call todolist_create first.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the parent todo list.' },
          title: { type: 'string', description: 'The todo title or task description.' },
          notes: { type: 'string', description: 'Optional additional notes.' },
        },
        required: ['listId', 'title'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_CREATE, args),
    },

    todo_list: {
      description:
        'List the todo items in a specific todo list. You must specify the listId. ' +
        'Returns items as structured data; format them as a Markdown checklist in your reply.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the parent todo list.' },
          includeCompleted: {
            type: 'boolean',
            description: 'Whether to include completed todos. Defaults to true.',
          },
        },
        required: ['listId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_LIST, args),
    },

    todo_complete: {
      description:
        'Mark a todo item as completed. You must specify the listId of the parent list.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the parent todo list.' },
          id: { type: 'string', description: 'The UUID of the todo item.' },
        },
        required: ['listId', 'id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_COMPLETE, args),
    },

    todo_update: {
      description:
        'Update the title, notes, or completion status of a todo item. You must specify the listId of the parent list.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the parent todo list.' },
          id: { type: 'string', description: 'The UUID of the todo item to update.' },
          title: { type: 'string', description: 'New title.' },
          notes: { type: 'string', description: 'New notes.' },
          isCompleted: { type: 'boolean', description: 'New completion status.' },
        },
        required: ['listId', 'id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TODO_UPDATE, args),
    },

    todo_delete: {
      description:
        'Permanently delete a todo item. You must specify the listId of the parent list.',
      parametersSchema: {
        type: 'object',
        properties: {
          listId: { type: 'string', description: 'The UUID of the parent todo list.' },
          id: { type: 'string', description: 'The UUID of the todo item.' },
        },
        required: ['listId', 'id'],
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

    table_batch_add_rows: {
      description:
        'Add 2 to 10 new rows to a table in one call. Each rows item must provide a cellData object whose keys are column keys.',
      parametersSchema: {
        type: 'object',
        properties: {
          resourceId: { type: 'string', description: 'The table identifier.' },
          rows: {
            type: 'array',
            minItems: 2,
            maxItems: 10,
            description: 'An array of row payloads to insert.',
            items: {
              type: 'object',
              properties: {
                cellData: {
                  type: 'object',
                  description: 'Key-value pairs where keys are column keys and values are cell strings.',
                  additionalProperties: true,
                },
              },
              required: ['cellData'],
              additionalProperties: false,
            },
          },
        },
        required: ['resourceId', 'rows'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS, args),
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

    // -------------------------------------------------------------------------
    // Note tools
    // -------------------------------------------------------------------------
    note_create: {
      description:
        'Create a new long-form Markdown note resource. Use when the user asks to save material, research, findings, summaries, or generated Markdown from chat into a note.',
      parametersSchema: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Short title for the note.' },
          body: { type: 'string', description: 'Markdown/plain-text body to save. Preserve useful Markdown formatting.' },
          isPublished: { type: 'boolean', description: 'Whether the note should appear in Resources. Defaults to true.' },
        },
        required: ['title', 'body'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_CREATE, args),
    },

    note_list: {
      description: 'List the user\'s published notes. Use before choosing a target note to update or append.',
      parametersSchema: {
        type: 'object',
        properties: {
          includeUnpublished: { type: 'boolean', description: 'Include hidden/unpublished notes when true.' },
        },
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_LIST, args),
    },

    note_get: {
      description: 'Get a full note by id, including the complete Markdown body.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
        },
        required: ['noteId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_GET, args),
    },

    note_update: {
      description: 'Update a note title, full body, or published visibility.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
          title: { type: 'string', description: 'New title.' },
          body: { type: 'string', description: 'Replacement Markdown/plain-text body.' },
          isPublished: { type: 'boolean', description: 'Whether the note appears in Resources.' },
        },
        required: ['noteId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_UPDATE, args),
    },

    note_delete: {
      description: 'Permanently delete a note. Use only when the user explicitly asks to delete it.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
        },
        required: ['noteId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_DELETE, args),
    },

    note_read_lines: {
      description: 'Read a line range from a long note without loading unrelated content.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
          startLine: { type: 'number', description: '1-based start line. Defaults to 1.' },
          endLine: { type: 'number', description: '1-based end line. Defaults to startLine.' },
        },
        required: ['noteId'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_READ_LINES, args),
    },

    note_append_lines: {
      description: 'Append Markdown/plain-text lines to the end of an existing note.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
          lines: {
            type: 'array',
            description: 'Lines to append, without trailing newline characters.',
            items: { type: 'string' },
          },
        },
        required: ['noteId', 'lines'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_APPEND_LINES, args),
    },

    note_replace_lines: {
      description: 'Replace a 1-based inclusive line range in an existing note.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
          startLine: { type: 'number', description: '1-based start line.' },
          endLine: { type: 'number', description: '1-based end line.' },
          lines: {
            type: 'array',
            description: 'Replacement lines.',
            items: { type: 'string' },
          },
        },
        required: ['noteId', 'startLine', 'endLine', 'lines'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_REPLACE_LINES, args),
    },

    note_delete_lines: {
      description: 'Delete a 1-based inclusive line range from an existing note.',
      parametersSchema: {
        type: 'object',
        properties: {
          noteId: { type: 'string', description: 'The UUID of the note.' },
          startLine: { type: 'number', description: '1-based start line.' },
          endLine: { type: 'number', description: '1-based end line.' },
        },
        required: ['noteId', 'startLine', 'endLine'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_NOTE_DELETE_LINES, args),
    },

    // -------------------------------------------------------------------------
    // Scheduled action tools
    // -------------------------------------------------------------------------
    scheduled_action_create: {
      description:
        'Create a new scheduled action that will run a prompt automatically at a recurring interval. ' +
        'Use when the user wants to automate a repeating task (e.g. daily standup, weekly report). ' +
        'intervalSeconds is the repeat period in seconds (minimum 60). ' +
        'scheduleExpr is a human-readable description of the schedule (e.g. "every day at 9am").',
      parametersSchema: {
        type: 'object',
        properties: {
          channelId: { type: 'string', description: 'The channel where the action will run.' },
          threadId: { type: 'string', description: 'Optional thread (sub-area) inside the channel. Omit for the main area.' },
          title: { type: 'string', description: 'Short human-readable title for the scheduled action.' },
          prompt: { type: 'string', description: 'The message that will be sent automatically on each run.' },
          scheduleExpr: { type: 'string', description: 'Human-readable schedule description, e.g. "every 30 minutes" or "daily at 9am".' },
          intervalSeconds: { type: 'number', description: 'Repeat interval in seconds. Minimum is 60 (1 minute).' },
          timezone: { type: 'string', description: 'IANA timezone string, e.g. "America/New_York". Defaults to UTC.' },
        },
        required: ['channelId', 'title', 'prompt', 'scheduleExpr', 'intervalSeconds'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_CREATE, args),
    },

    scheduled_action_list: {
      description: 'List all scheduled actions for the current user. Returns active and paused actions.',
      parametersSchema: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_LIST, args),
    },

    scheduled_action_get: {
      description: 'Get details of a specific scheduled action by its id.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Scheduled action identifier.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_GET, args),
    },

    scheduled_action_update: {
      description:
        'Update one or more fields of an existing scheduled action. Only the provided fields are changed.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Scheduled action identifier.' },
          title: { type: 'string', description: 'New title.' },
          prompt: { type: 'string', description: 'New prompt text.' },
          scheduleExpr: { type: 'string', description: 'New human-readable schedule description.' },
          intervalSeconds: { type: 'number', description: 'New repeat interval in seconds (minimum 60).' },
          timezone: { type: 'string', description: 'New IANA timezone string.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_UPDATE, args),
    },

    scheduled_action_pause: {
      description: 'Pause a scheduled action so it stops running until resumed.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Scheduled action identifier.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_PAUSE, args),
    },

    scheduled_action_resume: {
      description: 'Resume a paused scheduled action. The next run will be scheduled from now.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Scheduled action identifier.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_RESUME, args),
    },

    scheduled_action_delete: {
      description: 'Permanently delete a scheduled action. This cannot be undone.',
      parametersSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Scheduled action identifier.' },
        },
        required: ['id'],
        additionalProperties: false,
      },
      execute: (args) => runTool(INTERNAL_TOOL_SCHEDULED_ACTION_DELETE, args),
    },
  };
}
