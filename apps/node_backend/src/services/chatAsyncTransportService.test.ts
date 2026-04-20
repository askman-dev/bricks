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
  listSessionHistory,
  listUserScopes,
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
      .mockResolvedValueOnce({ rows: [], rowCount: 0 })             // SELECT existing metadata
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
    expect(clientQueryMock).toHaveBeenCalledTimes(6);
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

  it('upsertMessages preserves existing server metadata keys', async () => {
    const clientQueryMock = vi
        .fn()
        .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // BEGIN
        .mockResolvedValueOnce({ rows: [{ counter: 12 }], rowCount: 1 }) // counter++
        .mockResolvedValueOnce({
          rows: [
            {
              metadata: JSON.stringify({
                source: 'backend.respond.openclaw',
                pendingAssistantMessageId: 'msg-assistant-1',
              }),
            },
          ],
          rowCount: 1,
        })
        .mockResolvedValueOnce({ rows: [], rowCount: 1 }) // INSERT message
        .mockResolvedValueOnce({ rows: [], rowCount: 1 }) // checkpoint
        .mockResolvedValueOnce({ rows: [], rowCount: 0 }); // COMMIT

    connectMock.mockResolvedValueOnce({
      query: clientQueryMock,
      release: vi.fn(),
    });

    await upsertMessages('u-1', [
      {
        messageId: 'msg-user-1',
        taskId: 'task-1',
        channelId: 'default',
        sessionId: 'session:default:main',
        threadId: null,
        role: 'user',
        content: 'hello',
        taskState: 'dispatched',
        checkpointCursor: null,
        metadata: { resolvedBotId: 'ask' },
        createdAt: null,
      },
    ]);

    expect(clientQueryMock).toHaveBeenNthCalledWith(
      4,
      expect.stringContaining('INSERT INTO chat_messages'),
      expect.arrayContaining([
        JSON.stringify({
          source: 'backend.respond.openclaw',
          pendingAssistantMessageId: 'msg-assistant-1',
          resolvedBotId: 'ask',
        }),
      ]),
    );
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

  it('listSessionHistory returns createdAt-ordered timeline window', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          seq_id: 12,
          write_seq: 51,
          message_id: 'a-1',
          task_id: 'task-1',
          channel_id: 'default',
          session_id: 'session:default:main',
          thread_id: null,
          role: 'assistant',
          content: 'reply',
          task_state: 'completed',
          checkpoint_cursor: null,
          metadata: null,
          created_at: '2026-04-20T08:00:01.000Z',
          updated_at: '2026-04-20T08:00:02.000Z',
        },
      ],
      rowCount: 1,
    });

    const result = await listSessionHistory('u-1', 'session:default:main', {
      limit: 100,
    });

    expect(queryMock).toHaveBeenCalledWith(
      expect.stringContaining('ORDER BY created_at DESC, seq_id DESC'),
      ['u-1', 'session:default:main', 100],
    );
    expect(result.messages).toHaveLength(1);
    expect(result.messages[0].messageId).toBe('a-1');
    expect(result.lastSeqId).toBe(51);
  });

  it('listUserScopes returns distinct scopes ordered by latest activity', async () => {
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          channel_id: 'channel-2',
          thread_id: 'main',
          session_id: 'session:channel-2:main',
          last_activity_at: '2026-04-09T10:00:00.000Z',
        },
        {
          channel_id: 'default',
          thread_id: null,
          session_id: 'session:default:main',
          last_activity_at: '2026-04-08T10:00:00.000Z',
        },
      ],
      rowCount: 2,
    });
    queryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });

    const scopes = await listUserScopes('u-1');
    expect(scopes).toEqual([
      {
        channelId: 'channel-2',
        threadId: 'main',
        sessionId: 'session:channel-2:main',
        lastActivityAt: '2026-04-09T10:00:00.000Z',
      },
      {
        channelId: 'default',
        threadId: 'main',
        sessionId: 'session:default:main',
        lastActivityAt: '2026-04-08T10:00:00.000Z',
      },
    ]);
  });

  it('listUserScopes includes configured scopes without message history', async () => {
    queryMock.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    queryMock.mockResolvedValueOnce({
      rows: [
        {
          scope_type: 'channel',
          channel_id: 'openclaw-lab',
          thread_id: '',
          router: 'openclaw',
          created_at: '2026-04-17T07:00:00.000Z',
          updated_at: '2026-04-17T07:00:00.000Z',
        },
      ],
      rowCount: 1,
    });

    const scopes = await listUserScopes('u-1');

    expect(scopes).toEqual([
      {
        channelId: 'openclaw-lab',
        threadId: 'main',
        sessionId: 'session:openclaw-lab:main',
        lastActivityAt: null,
      },
    ]);
  });
});
