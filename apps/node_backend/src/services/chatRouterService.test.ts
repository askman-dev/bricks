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
  CHAT_ROUTER_DEFAULT,
  buildChatSessionId,
  deleteChatScopeSetting,
  listChatScopeSettings,
  normalizeChatThreadId,
  resolveChatRouter,
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

  it('lists scope settings with nullable channel-level thread id', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          scope_type: 'channel',
          channel_id: 'default',
          thread_id: '',
          router: 'openclaw',
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
        router: 'openclaw',
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
          router: 'default',
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
      router: 'default',
    });

    expect(setting.threadId).toBe('main');
    expect(queryMock).toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO chat_scope_settings'),
      ['u-1', 'thread', 'default', 'main', 'default'],
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

    expect(router).toBe(CHAT_ROUTER_DEFAULT);
  });
});
