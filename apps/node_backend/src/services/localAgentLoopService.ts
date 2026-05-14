import {
  buildChatSessionId,
  type ChatRouter,
  CHAT_ROUTER_LOCAL,
  type ChatScopeType,
  normalizeChatThreadId,
  upsertChatScopeSetting,
} from './chatRouterService.js';
import { upsertChatChannelName } from './chatChannelNameService.js';
import type { AgentTool } from '../llm/types.js';

export const INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET = 'chat.channel.instruction.set';
export const INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET = 'chat.thread.instruction.set';
export const INTERNAL_TOOL_CHAT_CHANNEL_CREATE = 'chat.channel.create';
export const INTERNAL_TOOL_CHAT_THREAD_CREATE = 'chat.thread.create';
export const INTERNAL_TOOL_CHAT_CHANNEL_RENAME = 'chat.channel.rename';

export const INTERNAL_TOOLS = [
  INTERNAL_TOOL_CHAT_CHANNEL_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_THREAD_INSTRUCTION_SET,
  INTERNAL_TOOL_CHAT_CHANNEL_CREATE,
  INTERNAL_TOOL_CHAT_THREAD_CREATE,
  INTERNAL_TOOL_CHAT_CHANNEL_RENAME,
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
  };
}
