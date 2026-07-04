import { beforeEach, describe, expect, it, vi } from 'vitest';

const { queryMock } = vi.hoisted(() => ({
  queryMock: vi.fn(),
}));

vi.mock('../db/index.js', () => ({
  default: {
    query: queryMock,
  },
}));

import {
  CHAT_ROUTER_LOCAL,
  buildChatSessionId,
  deleteChatScopeSetting,
  listChatScopeSettings,
  normalizeChatRouterValue,
  normalizeChatThreadId,
  resolveChatScopeRouting,
  resolveChatRouter,
  resolveScopeInstructions,
  upsertChatScopeSetting,
} from './chatRouterService.js';

describe('chatRouterService', () => {
  beforeEach(() => {
    queryMock.mockReset();
  });

  it('normalizes empty thread ids to main and builds session ids consistently', () => {
    expect(normalizeChatThreadId(null)).toBe('main');
    expect(normalizeChatThreadId('')).toBe('main');
    expect(buildChatSessionId('channel-a', null)).toBe('session:channel-a:main');
    expect(buildChatSessionId('channel-a', 'sub-1')).toBe('session:channel-a:sub-1');
  });

  it('normalizes legacy router values to dispatch strategy values', () => {
    expect(normalizeChatRouterValue('default')).toBe('local');
    expect(normalizeChatRouterValue('openclaw')).toBe('plugin');
    expect(normalizeChatRouterValue('local')).toBe('local');
    expect(normalizeChatRouterValue('plugin')).toBe('plugin');
    expect(normalizeChatRouterValue('unknown')).toBeNull();
  });

  it('lists scope settings with nullable channel-level thread id', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          scope_type: 'channel',
          channel_id: 'default',
          thread_id: '',
          router: 'openclaw',
          node_id: 'node_default',
          instructions: null,
          created_at: '2026-04-17T07:00:00.000Z',
          updated_at: '2026-04-17T07:05:00.000Z',
        },
      ],
      rowCount: 1,
    });

    const settings = await listChatScopeSettings('u-1');

    expect(settings).toEqual([
      {
        scopeType: 'channel',
        channelId: 'default',
        threadId: null,
        router: 'plugin',
        nodeId: 'node_default',
        instructions: null,
        outputTone: { type: 'preset', preset: 'direct' },
        inputGrammarFixerEnabled: false,
        createdAt: '2026-04-17T07:00:00.000Z',
        updatedAt: '2026-04-17T07:05:00.000Z',
      },
    ]);
  });

  it('upserts thread scope settings using normalized main thread id', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          scope_type: 'thread',
          channel_id: 'default',
          thread_id: 'main',
          router: 'local',
          node_id: 'node_default',
          instructions: null,
          created_at: '2026-04-17T07:00:00.000Z',
          updated_at: '2026-04-17T07:05:00.000Z',
        },
      ],
      rowCount: 1,
    });

    const setting = await upsertChatScopeSetting('u-1', {
      scopeType: 'thread',
      channelId: 'default',
      threadId: null,
      router: 'local',
      nodeId: 'node_default',
    });

    expect(setting.threadId).toBe('main');
    expect(setting.nodeId).toBe('node_default');
    expect(setting.instructions).toBeNull();
    expect(queryMock).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO chat_scope_settings'),
      ['u-1', 'thread', 'default', 'main', 'local', 'node_default', null],
    );
  });

  it('deletes channel scope settings with empty storage thread id', async () => {
    queryMock.mockResolvedValueOnce({ rowCount: 1, rows: [] });

    const result = await deleteChatScopeSetting('u-1', {
      scopeType: 'channel',
      channelId: 'default',
      threadId: null,
    });

    expect(result.deleted).toBe(true);
    expect(queryMock).toHaveBeenCalledWith(
      expect.stringContaining('DELETE FROM chat_scope_settings'),
      ['u-1', 'channel', 'default', ''],
    );
  });

  it('falls back to default router when no explicit setting exists', async () => {
    queryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });

    const router = await resolveChatRouter('u-1', {
      channelId: 'default',
      threadId: 'main',
    });

    expect(router).toBe(CHAT_ROUTER_LOCAL);
  });

  it('resolves router and node id together for scope routing', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [{ router: 'openclaw', node_id: 'node_default' }],
      rowCount: 1,
    });

    const routing = await resolveChatScopeRouting('u-1', {
      channelId: 'default',
      threadId: 'main',
    });

    expect(routing).toEqual({
      router: 'plugin',
      nodeId: 'node_default',
    });
  });

  it('resolves scope instructions for channel and sub-section', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        { scope_type: 'channel', instructions: 'channel-level context' },
        { scope_type: 'thread', instructions: 'section-specific context' },
      ],
      rowCount: 2,
    });

    const result = await resolveScopeInstructions('u-1', {
      channelId: 'channel-a',
      threadId: 'sub-1',
    });

    expect(result.channelInstructions).toBe('channel-level context');
    expect(result.threadInstructions).toBe('section-specific context');
  });

  it('resolves channel output tone and grammar fixer settings', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          scope_type: 'channel',
          instructions: 'channel context',
          output_tone_type: 'custom',
          output_tone_preset: null,
          output_tone_custom: 'Use plain technical language.',
          input_grammar_fixer_enabled: true,
        },
      ],
      rowCount: 1,
    });

    const result = await resolveScopeInstructions('u-1', {
      channelId: 'channel-a',
      threadId: 'main',
    });

    expect(result.channelOutputTone).toEqual({
      type: 'custom',
      instruction: 'Use plain technical language.',
    });
    expect(result.inputGrammarFixerEnabled).toBe(true);
  });

  it('returns null thread instructions when in main section', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        { scope_type: 'channel', instructions: 'channel context' },
      ],
      rowCount: 1,
    });

    const result = await resolveScopeInstructions('u-1', {
      channelId: 'channel-a',
      threadId: 'main',
    });

    expect(result.channelInstructions).toBe('channel context');
    expect(result.threadInstructions).toBeNull();
  });

  it('returns nulls when no instructions are stored', async () => {
    queryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });

    const result = await resolveScopeInstructions('u-1', {
      channelId: 'channel-a',
      threadId: 'sub-1',
    });

    expect(result.channelInstructions).toBeNull();
    expect(result.threadInstructions).toBeNull();
  });
});
