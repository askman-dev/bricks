import pool from '../db/index.js';

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
  const existing = await pool.query<ChatTaskRow>(
    `SELECT task_id, session_id, state, accepted_at
       FROM chat_tasks
      WHERE user_id = $1 AND idempotency_key = $2
      LIMIT 1`,
    [userId, input.idempotencyKey],
  );

  if (existing.rows[0]) {
    const row = existing.rows[0];
    return {
      taskId: row.task_id,
      sessionId: row.session_id,
      state: row.state,
      acceptedAt: row.accepted_at,
    };
  }

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
      RETURNING task_id, session_id, state, accepted_at`,
    [
      input.taskId,
      userId,
      input.channelId,
      input.sessionId,
      input.threadId,
      input.resolvedBotId,
      input.resolvedSkillId,
      input.idempotencyKey,
    ],
  );

  const row = inserted.rows[0];
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

  for (const message of messages) {
    await pool.query(
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
          created_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,COALESCE($12, NOW()))
        ON CONFLICT (user_id, message_id)
        DO UPDATE SET
          content = EXCLUDED.content,
          task_state = EXCLUDED.task_state,
          checkpoint_cursor = EXCLUDED.checkpoint_cursor,
          metadata = EXCLUDED.metadata,
          updated_at = NOW()`,
      [
        message.messageId,
        userId,
        message.taskId,
        message.channelId,
        message.sessionId,
        message.threadId,
        message.role,
        message.content,
        message.taskState,
        message.checkpointCursor,
        JSON.stringify(message.metadata ?? {}),
        message.createdAt,
      ],
    );
  }

  const sessionId = messages[messages.length - 1].sessionId;
  const maxResult = await pool.query<{ max_seq: number | null }>(
    `SELECT MAX(seq_id) AS max_seq
       FROM chat_messages
      WHERE user_id = $1 AND session_id = $2`,
    [userId, sessionId],
  );
  const lastSeq = Number(maxResult.rows[0]?.max_seq ?? 0);

  await pool.query(
    `INSERT INTO chat_sync_checkpoints (user_id, session_id, last_seq_id)
      VALUES ($1, $2, $3)
      ON CONFLICT (user_id, session_id)
      DO UPDATE SET last_seq_id = EXCLUDED.last_seq_id, updated_at = NOW()`,
    [userId, sessionId, lastSeq],
  );

  return { lastSeqId: lastSeq };
}

export async function syncMessages(
  userId: string,
  sessionId: string,
  afterSeq: number,
): Promise<{ messages: ReturnType<typeof toMessageDto>[]; lastSeqId: number }> {
  const result = await pool.query<ChatMessageRow>(
    `SELECT seq_id, message_id, task_id, channel_id, session_id, thread_id,
            role, content, task_state, checkpoint_cursor, metadata, created_at, updated_at
       FROM chat_messages
      WHERE user_id = $1 AND session_id = $2 AND seq_id > $3
      ORDER BY seq_id ASC`,
    [userId, sessionId, afterSeq],
  );

  const messages = result.rows.map(toMessageDto);
  const lastSeqId = messages.length > 0 ? messages[messages.length - 1].seqId : afterSeq;
  return { messages, lastSeqId };
}
