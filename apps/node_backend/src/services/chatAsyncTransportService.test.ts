import { beforeEach, describe, expect, it, vi } from 'vitest';

const { queryMock, connectMock } = vi.hoisted(() => ({
  queryMock: vi.fn(),
  connectMock: vi.fn(),
}));

vi.mock('../db/index.js', () => ({
  default: {
    query: queryMock,
    connect: connectMock,
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
    connectMock.mockReset();
  });

  it('acceptTask inserts new task and returns it', async () => {
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

  it('acceptTask returns existing row for idempotency key replay', async () => {
    // INSERT ON CONFLICT DO NOTHING returns no rows (conflict)
    queryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    // SELECT returns the existing row
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
    expect(queryMock).toHaveBeenCalledTimes(2);
  });

  it('upsertMessages wraps in transaction and returns write_seq cursor', async () => {
    const clientQueryMock = vi.fn()
      .mockResolvedValueOnce({ rows: [], rowCount: 0 })             // BEGIN
      .mockResolvedValueOnce({ rows: [{ counter: 11 }], rowCount: 1 }) // counter++
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })             // INSERT message
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })             // INSERT checkpoint
      .mockResolvedValueOnce({ rows: [], rowCount: 0 });            // COMMIT

    connectMock.mockResolvedValueOnce({
      query: clientQueryMock,
      release: vi.fn(),
    });

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
        checkpointCursor: null,
        metadata: { traceId: 'trace-1' },
        createdAt: null,
      },
    ]);

    expect(result.lastSeqId).toBe(11);
    expect(clientQueryMock).toHaveBeenCalledTimes(5);
  });

  it('upsertMessages rolls back on error', async () => {
    const clientQueryMock = vi.fn()
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // BEGIN
      .mockRejectedValueOnce(new Error('DB error'));    // counter++ fails

    const releaseMock = vi.fn();
    connectMock.mockResolvedValueOnce({
      query: clientQueryMock,
      release: releaseMock,
    });

    // Patch ROLLBACK to succeed after the failure
    clientQueryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });

    await expect(
      upsertMessages('u-1', [
        {
          messageId: 'msg-err',
          taskId: null,
          channelId: 'default',
          sessionId: 'session:default:main',
          threadId: null,
          role: 'user',
          content: 'hello',
          taskState: null,
          checkpointCursor: null,
          metadata: null,
          createdAt: null,
        },
      ]),
    ).rejects.toThrow('DB error');

    expect(releaseMock).toHaveBeenCalled();
  });

  it('syncMessages returns ordered deltas using write_seq cursor', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          seq_id: 5,
          write_seq: 7,
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
    expect(result.lastSeqId).toBe(7);
    expect(result.messages).toHaveLength(1);
    expect(result.messages[0].messageId).toBe('m-1');
    expect(result.messages[0].writeSeq).toBe(7);
  });
});
