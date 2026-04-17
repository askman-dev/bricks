import { beforeEach, describe, expect, it, vi } from 'vitest';

const { queryMock, upsertMessagesMock } = vi.hoisted(() => ({
  queryMock: vi.fn(),
  upsertMessagesMock: vi.fn(async () => ({ lastSeqId: 99 })),
}));

vi.mock('../db/index.js', () => ({
  default: {
    query: queryMock,
  },
}));

vi.mock('./chatAsyncTransportService.js', () => ({
  upsertMessages: upsertMessagesMock,
}));

import {
  createPlatformMessage,
  listPlatformEvents,
  patchPlatformMessage,
} from './platformIntegrationService.js';

describe('platformIntegrationService', () => {
  beforeEach(() => {
    queryMock.mockReset();
    upsertMessagesMock.mockClear();
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
});
