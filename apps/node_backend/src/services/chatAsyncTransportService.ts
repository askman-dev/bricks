import pool from '../db/index.js';
import {
  buildChatSessionId,
  listChatScopeSettings,
  normalizeChatThreadId,
} from './chatRouterService.js';

export interface AcceptTaskInput {
  taskId: string;
  idempotencyKey: string;
  channelId: string;
  sessionId: string;
  threadId: string | null;
  resolvedBotId: string | null;
  resolvedSkillId: string | null;
}

export interface AcceptedTask {
  taskId: string;
  sessionId: string;
  state: string;
  acceptedAt: string;
}

export interface MessageUpsertInput {
  messageId: string;
  taskId: string | null;
  channelId: string;
  sessionId: string;
  threadId: string | null;
  role: string;
  content: string;
  taskState: string | null;
  checkpointCursor: string | null;
  metadata: Record<string, unknown> | null;
  createdAt: string | null;
}

interface ChatMessageRow {
  seq_id: number;
  write_seq: number;
  message_id: string;
  task_id: string | null;
  channel_id: string;
  session_id: string;
  thread_id: string | null;
  role: string;
  content: string;
  task_state: string | null;
  checkpoint_cursor: string | null;
  metadata: unknown;
  created_at: string;
  updated_at: string;
}

interface ChatTaskRow {
  task_id: string;
  session_id: string;
  state: string;
  accepted_at: string;
}

interface ChatScopeRow {
  channel_id: string;
  thread_id: string | null;
  session_id: string;
  last_activity_at: string;
}

export interface ChatPersistedScope {
  channelId: string;
  threadId: string;
  sessionId: string;
  lastActivityAt: string | null;
}

function parseMetadata(raw: unknown): Record<string, unknown> | null {
  if (raw == null) return null;
  if (typeof raw === 'string' && raw.trim().length > 0) {
    try {
      const decoded = JSON.parse(raw);
      if (decoded && typeof decoded === 'object' && !Array.isArray(decoded)) {
        return decoded as Record<string, unknown>;
      }
    } catch (_) {
      return null;
    }
  }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return null;
}

function toMessageDto(row: ChatMessageRow) {
  return {
    seqId: row.seq_id,
    writeSeq: row.write_seq,
    messageId: row.message_id,
    taskId: row.task_id,
    channelId: row.channel_id,
    sessionId: row.session_id,
    threadId: row.thread_id,
    role: row.role,
    content: row.content,
    taskState: row.task_state,
    checkpointCursor: row.checkpoint_cursor,
    metadata: parseMetadata(row.metadata),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function acceptTask(
  userId: string,
  input: AcceptTaskInput,
): Promise<AcceptedTask> {
  // Attempt an atomic insert; DO NOTHING on conflict avoids a race between
  // a SELECT and a subsequent INSERT that can produce duplicate-key errors.
  const inserted = await pool.query<ChatTaskRow>(
    `INSERT INTO chat_tasks (
        task_id,
        user_id,
        channel_id,
        session_id,
        thread_id,
        resolved_bot_id,
        resolved_skill_id,
        idempotency_key,
        state
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'accepted')
      ON CONFLICT (user_id, idempotency_key) DO NOTHING
      RETURNING task_id, session_id, state, accepted_at`,
    [
      input.taskId,
      userId,
      input.channelId,
      input.sessionId,
      input.threadId ?? null,
      input.resolvedBotId ?? null,
      input.resolvedSkillId ?? null,
      input.idempotencyKey,
    ],
  );

  if (inserted.rows[0]) {
    const row = inserted.rows[0];
    return {
      taskId: row.task_id,
      sessionId: row.session_id,
      state: row.state,
      acceptedAt: row.accepted_at,
    };
  }

  // Conflict: another concurrent request already inserted this idempotency key.
  const existing = await pool.query<ChatTaskRow>(
    `SELECT task_id, session_id, state, accepted_at
       FROM chat_tasks
      WHERE user_id = $1 AND idempotency_key = $2
      LIMIT 1`,
    [userId, input.idempotencyKey],
  );

  const row = existing.rows[0];
  return {
    taskId: row.task_id,
    sessionId: row.session_id,
    state: row.state,
    acceptedAt: row.accepted_at,
  };
}

export async function upsertMessages(
  userId: string,
  messages: MessageUpsertInput[],
): Promise<{ lastSeqId: number }> {
  if (messages.length === 0) {
    return { lastSeqId: 0 };
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let lastWriteSeq = 0;
    for (const message of messages) {
      // Advance the monotonic write-sequence counter atomically so that
      // updates to existing messages receive a new cursor value and will be
      // returned by subsequent incremental syncMessages calls.
      const seqResult = await client.query<{ counter: number }>(
        `UPDATE chat_write_seq_counter SET counter = counter + 1 WHERE id = 1 RETURNING counter`,
        [],
      );
      if (!seqResult.rows[0]) {
        throw new Error(
          'chat_write_seq_counter row missing; ensure migration 008 has been applied',
        );
      }
      const writeSeq = Number(seqResult.rows[0].counter);

      const existingMessage = await client.query<{ metadata: unknown }>(
        `SELECT metadata
           FROM chat_messages
          WHERE user_id = $1 AND message_id = $2
          LIMIT 1`,
        [userId, message.messageId],
      );
      const mergedMetadata = {
        ...(parseMetadata(existingMessage.rows[0]?.metadata) ?? {}),
        ...(message.metadata ?? {}),
      };

      await client.query(
        `INSERT INTO chat_messages (
            message_id,
            user_id,
            task_id,
            channel_id,
            session_id,
            thread_id,
            role,
            content,
            task_state,
            checkpoint_cursor,
            metadata,
            created_at,
            write_seq
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,COALESCE($12, CURRENT_TIMESTAMP),$13)
          ON CONFLICT (user_id, message_id)
          DO UPDATE SET
            content = EXCLUDED.content,
            task_state = EXCLUDED.task_state,
            checkpoint_cursor = EXCLUDED.checkpoint_cursor,
            metadata = EXCLUDED.metadata,
            write_seq = EXCLUDED.write_seq,
            updated_at = CURRENT_TIMESTAMP`,
        [
          message.messageId,
          userId,
          message.taskId ?? null,
          message.channelId,
          message.sessionId,
          message.threadId ?? null,
          message.role,
          message.content,
          message.taskState ?? null,
          message.checkpointCursor ?? null,
          JSON.stringify(mergedMetadata),
          message.createdAt ?? null,
          writeSeq,
        ],
      );
      lastWriteSeq = writeSeq;
    }

    const sessionId = messages[messages.length - 1].sessionId;
    await client.query(
      `INSERT INTO chat_sync_checkpoints (user_id, session_id, last_seq_id)
        VALUES ($1, $2, $3)
        ON CONFLICT (user_id, session_id)
        DO UPDATE SET last_seq_id = EXCLUDED.last_seq_id, updated_at = CURRENT_TIMESTAMP`,
      [userId, sessionId, lastWriteSeq],
    );

    await client.query('COMMIT');
    return { lastSeqId: lastWriteSeq };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function syncMessages(
  userId: string,
  sessionId: string,
  afterSeq: number,
  options: { limit?: number } = {},
): Promise<{ messages: ReturnType<typeof toMessageDto>[]; lastSeqId: number }> {
  const limit = options.limit == null ? null : Math.max(1, Math.min(options.limit, 500));

  const baseQuery = `SELECT seq_id, write_seq, message_id, task_id, channel_id, session_id, thread_id,
            role, content, task_state, checkpoint_cursor, metadata, created_at, updated_at
       FROM chat_messages
      WHERE user_id = $1 AND session_id = $2 AND write_seq > $3`;

  const result =
    afterSeq === 0 && limit != null
      ? await pool.query<ChatMessageRow>(
          `SELECT * FROM (
             ${baseQuery}
             ORDER BY write_seq DESC
             LIMIT $4
           ) recent
           ORDER BY write_seq ASC`,
          [userId, sessionId, afterSeq, limit],
        )
      : await pool.query<ChatMessageRow>(
          `${baseQuery}
           ORDER BY write_seq ASC`,
          [userId, sessionId, afterSeq],
        );

  const messages = result.rows.map(toMessageDto);
  const lastSeqId = messages.length > 0 ? messages[messages.length - 1].writeSeq : afterSeq;
  return { messages, lastSeqId };
}


interface ThreadForkRow {
  parent_session_id: string;
  fork_write_seq: string;
}

/**
 * Look up the fork record for a session, if one exists.
 * Returns null when the session is not a fork.
 */
async function getThreadFork(
  userId: string,
  sessionId: string,
): Promise<{ parentSessionId: string; forkWriteSeq: bigint } | null> {
  const result = await pool.query<ThreadForkRow>(
    `SELECT parent_session_id, fork_write_seq
       FROM chat_thread_forks
      WHERE user_id = $1
        AND forked_session_id = $2
      LIMIT 1`,
    [userId, sessionId],
  );
  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return {
    parentSessionId: row.parent_session_id,
    forkWriteSeq: BigInt(row.fork_write_seq),
  };
}

/**
 * Collect messages from rows into the budget, oldest-first.
 * rows must be supplied newest-first (ORDER BY write_seq DESC).
 */
function collectMessages(
  rows: ChatMessageRow[],
  budget: { used: number; maxChars: number },
): Array<{ role: 'user' | 'assistant'; content: string }> {
  const collected: Array<{ role: 'user' | 'assistant'; content: string }> = [];
  for (const row of rows) {
    const content = row.content?.trim() ?? '';
    if (!content) continue;
    if (budget.used + content.length > budget.maxChars) break;
    budget.used += content.length;
    collected.push({ role: row.role as 'user' | 'assistant', content });
  }
  return collected.reverse();
}

export async function listSessionMessagesForModel(
  userId: string,
  sessionId: string,
  options: { limit?: number; maxChars?: number } = {},
): Promise<Array<{ role: 'user' | 'assistant'; content: string }>> {
  const limit = Math.max(1, Math.min(options.limit ?? 40, 200));
  const maxChars = Math.max(200, Math.min(options.maxChars ?? 8000, 64000));
  const budget = { used: 0, maxChars };

  // Check if this session is a fork; if so, prepend parent context first.
  const fork = await getThreadFork(userId, sessionId);

  // Fetch own messages (newest-first so we can apply the char budget).
  const ownResult = await pool.query<ChatMessageRow>(
    `SELECT seq_id, write_seq, message_id, task_id, channel_id, session_id, thread_id,
            role, content, task_state, checkpoint_cursor, metadata, created_at, updated_at
       FROM chat_messages
      WHERE user_id = $1
        AND session_id = $2
        AND role IN ('user', 'assistant')
      ORDER BY write_seq DESC
      LIMIT $3`,
    [userId, sessionId, limit],
  );

  // Collect the forked session's own messages against the shared budget.
  const ownMessages = collectMessages(ownResult.rows, budget);

  if (!fork) {
    return ownMessages;
  }

  // Fetch parent messages up to (and including) the fork point.
  const parentResult = await pool.query<ChatMessageRow>(
    `SELECT seq_id, write_seq, message_id, task_id, channel_id, session_id, thread_id,
            role, content, task_state, checkpoint_cursor, metadata, created_at, updated_at
       FROM chat_messages
      WHERE user_id = $1
        AND session_id = $2
        AND role IN ('user', 'assistant')
        AND write_seq <= $3
      ORDER BY write_seq DESC
      LIMIT $4`,
    [userId, fork.parentSessionId, fork.forkWriteSeq, limit],
  );

  const parentMessages = collectMessages(parentResult.rows, budget);

  // Return parent context first (chronological), then the fork's own messages.
  return [...parentMessages, ...ownMessages];
}

export interface ForkThreadInput {
  userId: string;
  forkedSessionId: string;
  parentSessionId: string;
  forkMessageId: string;
}

export interface ForkThreadResult {
  forkedSessionId: string;
  parentSessionId: string;
  forkMessageId: string;
  forkWriteSeq: number;
}

/**
 * Record a thread fork in the database.
 * The fork point is identified by the parent message_id; its write_seq is
 * looked up at insert time so that context assembly can use a stable cursor.
 */
export async function forkThread(input: ForkThreadInput): Promise<ForkThreadResult> {
  const { userId, forkedSessionId, parentSessionId, forkMessageId } = input;

  // Look up the write_seq for the fork point message.
  const msgResult = await pool.query<{ write_seq: string }>(
    `SELECT write_seq FROM chat_messages
      WHERE user_id = $1
        AND session_id = $2
        AND message_id = $3
      LIMIT 1`,
    [userId, parentSessionId, forkMessageId],
  );
  if (msgResult.rows.length === 0) {
    throw new Error(`Fork message not found: ${forkMessageId}`);
  }
  const forkWriteSeq = Number(msgResult.rows[0].write_seq);

  await pool.query(
    `INSERT INTO chat_thread_forks
       (user_id, forked_session_id, parent_session_id, fork_message_id, fork_write_seq)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, forked_session_id) DO NOTHING`,
    [userId, forkedSessionId, parentSessionId, forkMessageId, forkWriteSeq],
  );

  return { forkedSessionId, parentSessionId, forkMessageId, forkWriteSeq };
}

export async function listUserScopes(userId: string): Promise<ChatPersistedScope[]> {
  const [result, settings] = await Promise.all([
    pool.query<ChatScopeRow>(
    `SELECT
        scope.channel_id,
        scope.thread_id,
        scope.session_id,
        MAX(scope.last_activity_at) AS last_activity_at
      FROM (
        SELECT
          channel_id,
          COALESCE(thread_id, 'main') AS thread_id,
          session_id,
          created_at AS last_activity_at
        FROM chat_messages
        WHERE user_id = $1
        UNION ALL
        SELECT
          channel_id,
          COALESCE(thread_id, 'main') AS thread_id,
          session_id,
          accepted_at AS last_activity_at
        FROM chat_tasks
        WHERE user_id = $1
      ) scope
       GROUP BY scope.channel_id, scope.thread_id, scope.session_id
       ORDER BY last_activity_at DESC`,
    [userId],
    ),
    listChatScopeSettings(userId),
  ]);

  const bySessionId = new Map<string, ChatPersistedScope>();
  for (const row of result.rows) {
    const threadId = normalizeChatThreadId(row.thread_id);
    bySessionId.set(row.session_id, {
      channelId: row.channel_id,
      threadId,
      sessionId: row.session_id,
      lastActivityAt: row.last_activity_at,
    });
  }

  for (const setting of settings) {
    const threadId =
      setting.scopeType === 'thread'
        ? normalizeChatThreadId(setting.threadId)
        : 'main';
    const sessionId = buildChatSessionId(setting.channelId, threadId);
    if (bySessionId.has(sessionId)) continue;
    bySessionId.set(sessionId, {
      channelId: setting.channelId,
      threadId,
      sessionId,
      lastActivityAt: null,
    });
  }

  return [...bySessionId.values()].sort((a, b) => {
    if (a.lastActivityAt && b.lastActivityAt) {
      return b.lastActivityAt.localeCompare(a.lastActivityAt);
    }
    if (b.lastActivityAt) return 1;
    if (a.lastActivityAt) return -1;
    return a.sessionId.localeCompare(b.sessionId);
  });
}
