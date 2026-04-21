import { beforeEach, describe, expect, it, vi } from 'vitest';

const { poolMock, queryMock, upsertMessagesMock } = vi.hoisted(() => {
  const queryMock = vi.fn();
  const upsertMessagesMock = vi.fn(async () => ({ lastSeqId: 99 }));
  return {
    poolMock: {
      dialect: 'postgres' as 'postgres' | 'turso',
      query: queryMock,
    },
    queryMock,
    upsertMessagesMock,
  };
});

vi.mock('../db/index.js', () => ({
  default: poolMock,
}));

vi.mock('./chatAsyncTransportService.js', () => ({
  upsertMessages: upsertMessagesMock,
}));

import {
  ackPlatformEvents,
  createPlatformMessage,
  listPlatformEvents,
  patchPlatformMessage,
} from './platformIntegrationService.js';

describe('platformIntegrationService', () => {
  beforeEach(() => {
    queryMock.mockReset();
    upsertMessagesMock.mockClear();
    poolMock.dialect = 'postgres';
  });

  it('lists only OpenClaw-ready user events with pending assistant metadata', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          write_seq: 5,
          message_id: 'msg-user-1',
          user_id: 'u-1',
          channel_id: 'default',
          session_id: 'session:default:main',
          thread_id: null,
          role: 'user',
          content: 'hello',
          created_at: '2026-04-17T07:00:00.000Z',
          metadata: JSON.stringify({
            pendingAssistantMessageId: 'msg-assistant-1',
          }),
        },
      ],
      rowCount: 1,
    });

    const response = await listPlatformEvents({ cursor: 'cur_0', userId: 'u-1' });

    expect(response.nextCursor).toBe('cur_5');
    expect(response.events).toHaveLength(1);
    expect(response.events[0].payload.metadata).toMatchObject({
      pendingAssistantMessageId: 'msg-assistant-1',
    });
  });

  it('marks assistant creates as dispatched', async () => {
    const result = await createPlatformMessage({
      userId: 'u-1',
      conversationId: 'session:default:main',
      channelId: 'default',
      role: 'assistant',
      text: 'processing',
      clientToken: 'msg-assistant-1',
    });

    expect(result.messageId).toBe('msg-assistant-1');
    expect(upsertMessagesMock).toHaveBeenCalledWith(
      'u-1',
      expect.arrayContaining([
        expect.objectContaining({
          messageId: 'msg-assistant-1',
          taskState: 'dispatched',
        }),
      ]),
    );
  });

  it('marks assistant patches as completed', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          message_id: 'msg-assistant-1',
          user_id: 'u-1',
          channel_id: 'default',
          session_id: 'session:default:main',
          thread_id: null,
          role: 'assistant',
          content: 'processing',
          metadata: JSON.stringify({ source: 'platform.messages.create' }),
          created_at: '2026-04-17T07:00:00.000Z',
          updated_at: '2026-04-17T07:00:01.000Z',
        },
      ],
      rowCount: 1,
    });

    const result = await patchPlatformMessage({
      userId: 'u-1',
      messageId: 'msg-assistant-1',
      text: 'done',
    });

    expect(result).toEqual({ messageId: 'msg-assistant-1', updated: true });
    expect(upsertMessagesMock).toHaveBeenCalledWith(
      'u-1',
      expect.arrayContaining([
        expect.objectContaining({
          messageId: 'msg-assistant-1',
          taskState: 'completed',
          content: 'done',
        }),
      ]),
    );
  });

  it('ack marks user message as completed and records plugin read marker', async () => {
    queryMock.mockResolvedValueOnce({ rowCount: 1, rows: [] });

    const result = await ackPlatformEvents({
      pluginId: 'plugin_local_main',
      userId: 'u-1',
      cursor: 'cur_5',
      ackedEventIds: ['evt_msg_msg-user-1_5'],
    });

    expect(result).toEqual({ ok: true });
    expect(queryMock).toHaveBeenCalledTimes(1);
    const [sql, params] = queryMock.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("SET task_state = 'completed'");
    expect(sql).toContain("AND task_state IN ('accepted', 'dispatched')");
    expect(sql).toContain('UNNEST($1::text[], $2::int[])');
    expect(sql).toContain('jsonb_set(');
    expect(params).toEqual([['msg-user-1'], [5], 'plugin_local_main', 'u-1']);
  });

  it('ack uses Turso-compatible JSON patch SQL when database dialect is turso', async () => {
    poolMock.dialect = 'turso';
    queryMock.mockResolvedValueOnce({ rowCount: 1, rows: [] });

    const result = await ackPlatformEvents({
      pluginId: 'plugin_local_main',
      userId: 'u-1',
      cursor: 'cur_5',
      ackedEventIds: ['evt_msg_msg-user-1_5', 'evt_msg_msg-user-2_8'],
    });

    expect(result).toEqual({ ok: true });
    expect(queryMock).toHaveBeenCalledTimes(1);
    const [sql, params] = queryMock.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("SET task_state = 'completed'");
    expect(sql).toContain("AND task_state IN ('accepted', 'dispatched')");
    expect(sql).toContain('json_patch(');
    expect(sql).toContain("json_object('pluginReadBy', json_object($1, CURRENT_TIMESTAMP))");
    expect(sql).not.toContain('UNNEST(');
    expect(sql).not.toContain('::jsonb');
    expect(params).toEqual(['plugin_local_main', 'msg-user-1', 5, 'msg-user-2', 8, 'u-1']);
  });

  it('chunks Turso ack updates into smaller statements', async () => {
    poolMock.dialect = 'turso';
    queryMock.mockResolvedValue({ rowCount: 1, rows: [] });

    const ackedEventIds = Array.from(
      { length: 51 },
      (_, index) => `evt_msg_msg-user-${index + 1}_${index + 1}`,
    );

    const result = await ackPlatformEvents({
      pluginId: 'plugin_local_main',
      userId: 'u-1',
      cursor: 'cur_51',
      ackedEventIds,
    });

    expect(result).toEqual({ ok: true });
    expect(queryMock).toHaveBeenCalledTimes(2);
    expect(queryMock.mock.calls[0]?.[1]).toHaveLength(102);
    expect(queryMock.mock.calls[1]?.[1]).toEqual(['plugin_local_main', 'msg-user-51', 51, 'u-1']);
  });

  it('rejects oversized ack batches before querying', async () => {
    const ackedEventIds = Array.from(
      { length: 201 },
      (_, index) => `evt_msg_msg-user-${index + 1}_${index + 1}`,
    );

    await expect(
      ackPlatformEvents({
        pluginId: 'plugin_local_main',
        userId: 'u-1',
        cursor: 'cur_201',
        ackedEventIds,
      }),
    ).rejects.toThrow('TOO_MANY_ACKED_EVENT_IDS');

    expect(queryMock).not.toHaveBeenCalled();
  });
});
