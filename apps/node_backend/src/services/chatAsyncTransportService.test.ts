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
  acceptTask,
  syncMessages,
  upsertMessages,
} from './chatAsyncTransportService.js';

describe('chatAsyncTransportService', () => {
  beforeEach(() => {
    queryMock.mockReset();
  });

  it('acceptTask returns existing row for idempotency key replay', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          task_id: 'task-1',
          session_id: 'session:default:main',
          state: 'accepted',
          accepted_at: '2026-04-07T06:00:00.000Z',
        },
      ],
      rowCount: 1,
    });

    const accepted = await acceptTask('u-1', {
      taskId: 'task-1',
      idempotencyKey: 'idem-1',
      channelId: 'default',
      sessionId: 'session:default:main',
      threadId: null,
      resolvedBotId: 'ask',
      resolvedSkillId: 'ask.default',
    });

    expect(accepted.taskId).toBe('task-1');
    expect(queryMock).toHaveBeenCalledTimes(1);
  });

  it('upsertMessages updates checkpoint and returns last sequence', async () => {
    queryMock
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [{ max_seq: 11 }], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [], rowCount: 1 });

    const result = await upsertMessages('u-1', [
      {
        messageId: 'msg-1',
        taskId: 'task-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        threadId: null,
        role: 'assistant',
        content: 'hello',
        taskState: 'completed',
        checkpointCursor: 'seq:11',
        metadata: { traceId: 'trace-1' },
        createdAt: null,
      },
    ]);

    expect(result.lastSeqId).toBe(11);
    expect(queryMock).toHaveBeenCalledTimes(3);
  });

  it('syncMessages returns ordered deltas and cursor', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          seq_id: 5,
          message_id: 'm-1',
          task_id: 'task-1',
          channel_id: 'default',
          session_id: 'session:default:main',
          thread_id: null,
          role: 'user',
          content: 'hi',
          task_state: 'accepted',
          checkpoint_cursor: null,
          metadata: JSON.stringify({ taskId: 'task-1' }),
          created_at: '2026-04-07T06:00:00.000Z',
          updated_at: '2026-04-07T06:00:00.000Z',
        },
      ],
      rowCount: 1,
    });

    const result = await syncMessages('u-1', 'session:default:main', 4);
    expect(result.lastSeqId).toBe(5);
    expect(result.messages).toHaveLength(1);
    expect(result.messages[0].messageId).toBe('m-1');
  });
});
