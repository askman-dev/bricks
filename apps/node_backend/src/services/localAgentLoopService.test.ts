import { describe, expect, it, vi, beforeEach } from 'vitest';

const upsertChatScopeSettingMock = vi.fn();
const upsertChatChannelNameMock = vi.fn();

vi.mock('./chatRouterService.js', () => ({
  CHAT_ROUTER_LOCAL: 'local',
  buildChatSessionId: (channelId: string, threadId?: string | null) =>
    `session:${channelId}:${threadId ?? 'main'}`,
  normalizeChatThreadId: (threadId?: string | null) => {
    const t = threadId?.trim();
    return t && t.length > 0 ? t : 'main';
  },
  upsertChatScopeSetting: upsertChatScopeSettingMock,
}));

vi.mock('./chatChannelNameService.js', () => ({
  upsertChatChannelName: upsertChatChannelNameMock,
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
});
