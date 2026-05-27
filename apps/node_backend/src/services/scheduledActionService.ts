import pool from '../db/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ScheduledActionStatus = 'active' | 'paused' | 'deleted';
export type ScheduledActionRunStatus = 'queued' | 'running' | 'completed' | 'failed';

export interface ScheduledAction {
  id: string;
  userId: string;
  channelId: string;
  threadId: string | null;
  title: string;
  prompt: string;
  scheduleExpr: string;
  intervalSeconds: number;
  timezone: string;
  nextRunAt: string;
  status: ScheduledActionStatus;
  createdAt: string;
  updatedAt: string;
}

export interface CreateScheduledActionInput {
  channelId: string;
  threadId?: string | null;
  title: string;
  prompt: string;
  scheduleExpr: string;
  intervalSeconds: number;
  timezone?: string;
}

export interface UpdateScheduledActionInput {
  title?: string;
  prompt?: string;
  scheduleExpr?: string;
  intervalSeconds?: number;
  timezone?: string;
}

export interface ScheduledActionRun {
  id: string;
  scheduledActionId: string;
  userId: string;
  channelId: string;
  threadId: string | null;
  scheduledFireAt: string;
  status: ScheduledActionRunStatus;
  startedAt: string | null;
  completedAt: string | null;
  errorText: string | null;
  chatTaskId: string | null;
  chatMessageId: string | null;
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Row types
// ---------------------------------------------------------------------------

interface ScheduledActionRow {
  id: string;
  user_id: string;
  channel_id: string;
  thread_id: string | null;
  title: string;
  prompt: string;
  schedule_expr: string;
  interval_seconds: number;
  timezone: string;
  next_run_at: string;
  status: string;
  created_at: string;
  updated_at: string;
}

interface ScheduledActionRunRow {
  id: string;
  scheduled_action_id: string;
  user_id: string;
  channel_id: string;
  thread_id: string | null;
  scheduled_fire_at: string;
  status: string;
  started_at: string | null;
  completed_at: string | null;
  error_text: string | null;
  chat_task_id: string | null;
  chat_message_id: string | null;
  created_at: string;
  updated_at: string;
}

// ---------------------------------------------------------------------------
// Mappers
// ---------------------------------------------------------------------------

function toActionDto(row: ScheduledActionRow): ScheduledAction {
  return {
    id: row.id,
    userId: row.user_id,
    channelId: row.channel_id,
    threadId: row.thread_id,
    title: row.title,
    prompt: row.prompt,
    scheduleExpr: row.schedule_expr,
    intervalSeconds: Number(row.interval_seconds),
    timezone: row.timezone,
    nextRunAt: row.next_run_at,
    status: row.status as ScheduledActionStatus,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toRunDto(row: ScheduledActionRunRow): ScheduledActionRun {
  return {
    id: row.id,
    scheduledActionId: row.scheduled_action_id,
    userId: row.user_id,
    channelId: row.channel_id,
    threadId: row.thread_id,
    scheduledFireAt: row.scheduled_fire_at,
    status: row.status as ScheduledActionRunStatus,
    startedAt: row.started_at,
    completedAt: row.completed_at,
    errorText: row.error_text,
    chatTaskId: row.chat_task_id,
    chatMessageId: row.chat_message_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

const ACTION_SELECT_COLS =
  'id, user_id, channel_id, thread_id, title, prompt, schedule_expr, interval_seconds, timezone, next_run_at, status, created_at, updated_at';

const RUN_SELECT_COLS =
  'id, scheduled_action_id, user_id, channel_id, thread_id, scheduled_fire_at, status, started_at, completed_at, error_text, chat_task_id, chat_message_id, created_at, updated_at';

// ---------------------------------------------------------------------------
// Schedule helpers
// ---------------------------------------------------------------------------

const MIN_INTERVAL_SECONDS = 60; // 1 minute minimum

/**
 * Clamp interval to a minimum of 1 minute and ensure it is a positive integer.
 */
export function clampIntervalSeconds(value: number): number {
  const n = Math.max(MIN_INTERVAL_SECONDS, Math.trunc(value));
  return Number.isFinite(n) ? n : MIN_INTERVAL_SECONDS;
}

/**
 * Compute the next run time after `fromDate` by adding `intervalSeconds`.
 * If `fromDate` is already in the past, the addition is anchored from now so
 * the action fires at `now + intervalSeconds` rather than a past time.
 * Note: this is a simple interval addition; it does not align to wall-clock
 * boundaries (e.g. "daily at 9 am").
 */
export function computeNextRunAt(fromDate: Date, intervalSeconds: number): Date {
  const now = Date.now();
  const base = Math.max(fromDate.getTime(), now);
  return new Date(base + intervalSeconds * 1000);
}

// ---------------------------------------------------------------------------
// CRUD
// ---------------------------------------------------------------------------

export async function listScheduledActions(userId: string): Promise<ScheduledAction[]> {
  const result = await pool.query<ScheduledActionRow>(
    `SELECT ${ACTION_SELECT_COLS}
       FROM scheduled_actions
      WHERE user_id = $1 AND status <> 'deleted'
      ORDER BY created_at ASC`,
    [userId],
  );
  return result.rows.map(toActionDto);
}

export async function getScheduledAction(
  userId: string,
  id: string,
): Promise<ScheduledAction | null> {
  const result = await pool.query<ScheduledActionRow>(
    `SELECT ${ACTION_SELECT_COLS}
       FROM scheduled_actions
      WHERE user_id = $1 AND id = $2 AND status <> 'deleted'`,
    [userId, id],
  );
  return result.rows[0] ? toActionDto(result.rows[0]) : null;
}

export async function createScheduledAction(
  userId: string,
  input: CreateScheduledActionInput,
): Promise<ScheduledAction> {
  const intervalSeconds = clampIntervalSeconds(input.intervalSeconds);
  const nextRunAt = new Date(Date.now() + intervalSeconds * 1000);

  const result = await pool.query<ScheduledActionRow>(
    `INSERT INTO scheduled_actions
         (user_id, channel_id, thread_id, title, prompt, schedule_expr, interval_seconds, timezone, next_run_at, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'active')
       RETURNING ${ACTION_SELECT_COLS}`,
    [
      userId,
      input.channelId,
      input.threadId ?? null,
      input.title.trim(),
      input.prompt.trim(),
      input.scheduleExpr.trim(),
      intervalSeconds,
      (input.timezone ?? 'UTC').trim(),
      nextRunAt.toISOString(),
    ],
  );
  return toActionDto(result.rows[0]);
}

export async function updateScheduledAction(
  userId: string,
  id: string,
  input: UpdateScheduledActionInput,
): Promise<ScheduledAction | null> {
  const setClauses: string[] = [];
  const values: unknown[] = [userId, id];
  let idx = 3;

  if (input.title !== undefined) {
    setClauses.push(`title = $${idx++}`);
    values.push(input.title.trim());
  }
  if (input.prompt !== undefined) {
    setClauses.push(`prompt = $${idx++}`);
    values.push(input.prompt.trim());
  }
  if (input.scheduleExpr !== undefined) {
    setClauses.push(`schedule_expr = $${idx++}`);
    values.push(input.scheduleExpr.trim());
  }
  if (input.intervalSeconds !== undefined) {
    const clamped = clampIntervalSeconds(input.intervalSeconds);
    setClauses.push(`interval_seconds = $${idx++}`);
    values.push(clamped);
  }
  if (input.timezone !== undefined) {
    setClauses.push(`timezone = $${idx++}`);
    values.push(input.timezone.trim());
  }

  if (setClauses.length === 0) {
    return getScheduledAction(userId, id);
  }

  const result = await pool.query<ScheduledActionRow>(
    `UPDATE scheduled_actions
        SET ${setClauses.join(', ')}
      WHERE user_id = $1 AND id = $2 AND status <> 'deleted'
      RETURNING ${ACTION_SELECT_COLS}`,
    values,
  );
  return result.rows[0] ? toActionDto(result.rows[0]) : null;
}

export async function pauseScheduledAction(
  userId: string,
  id: string,
): Promise<ScheduledAction | null> {
  const result = await pool.query<ScheduledActionRow>(
    `UPDATE scheduled_actions
        SET status = 'paused'
      WHERE user_id = $1 AND id = $2 AND status = 'active'
      RETURNING ${ACTION_SELECT_COLS}`,
    [userId, id],
  );
  return result.rows[0] ? toActionDto(result.rows[0]) : null;
}

export async function resumeScheduledAction(
  userId: string,
  id: string,
): Promise<ScheduledAction | null> {
  // Recompute next_run_at from now so the action fires at the next interval.
  const result = await pool.query<ScheduledActionRow>(
    `SELECT ${ACTION_SELECT_COLS}
       FROM scheduled_actions
      WHERE user_id = $1 AND id = $2 AND status = 'paused'`,
    [userId, id],
  );
  if (!result.rows[0]) return null;

  const action = toActionDto(result.rows[0]);
  const nextRunAt = computeNextRunAt(new Date(), action.intervalSeconds);

  const updated = await pool.query<ScheduledActionRow>(
    `UPDATE scheduled_actions
        SET status = 'active', next_run_at = $3
      WHERE user_id = $1 AND id = $2 AND status = 'paused'
      RETURNING ${ACTION_SELECT_COLS}`,
    [userId, id, nextRunAt.toISOString()],
  );
  return updated.rows[0] ? toActionDto(updated.rows[0]) : null;
}

export async function deleteScheduledAction(
  userId: string,
  id: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `UPDATE scheduled_actions
        SET status = 'deleted'
      WHERE user_id = $1 AND id = $2 AND status <> 'deleted'`,
    [userId, id],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}

// ---------------------------------------------------------------------------
// Cron tick helpers
// ---------------------------------------------------------------------------

const CRON_BATCH_SIZE = 5;

/**
 * Return up to CRON_BATCH_SIZE active scheduled actions that are due now.
 */
export async function queryDueActions(): Promise<ScheduledAction[]> {
  const result = await pool.query<ScheduledActionRow>(
    `SELECT ${ACTION_SELECT_COLS}
       FROM scheduled_actions
      WHERE status = 'active'
        AND next_run_at <= CURRENT_TIMESTAMP
      ORDER BY next_run_at ASC
      LIMIT $1`,
    [CRON_BATCH_SIZE],
  );
  return result.rows.map(toActionDto);
}

/**
 * Attempt to claim a scheduled action run for the given fire time.
 * Uses INSERT ... ON CONFLICT DO NOTHING so only one cron invocation wins.
 *
 * Returns the created run record on success, or null if already claimed.
 */
export async function claimScheduledActionRun(
  action: ScheduledAction,
  scheduledFireAt: Date,
): Promise<ScheduledActionRun | null> {
  const result = await pool.query<ScheduledActionRunRow>(
    `INSERT INTO scheduled_action_runs
         (scheduled_action_id, user_id, channel_id, thread_id, scheduled_fire_at, status)
       VALUES ($1,$2,$3,$4,$5,'queued')
       ON CONFLICT (scheduled_action_id, scheduled_fire_at) DO NOTHING
       RETURNING ${RUN_SELECT_COLS}`,
    [
      action.id,
      action.userId,
      action.channelId,
      action.threadId ?? null,
      scheduledFireAt.toISOString(),
    ],
  );
  return result.rows[0] ? toRunDto(result.rows[0]) : null;
}

/**
 * Advance next_run_at after a successful claim so the action is not re-queued
 * in the same cron tick.
 */
export async function advanceNextRunAt(
  actionId: string,
  currentNextRunAt: Date,
  intervalSeconds: number,
): Promise<void> {
  const nextRunAt = computeNextRunAt(currentNextRunAt, intervalSeconds);
  await pool.query(
    `UPDATE scheduled_actions
        SET next_run_at = $2
      WHERE id = $1`,
    [actionId, nextRunAt.toISOString()],
  );
}

/**
 * Mark a run as running and record started_at.
 */
export async function markRunStarted(runId: string): Promise<void> {
  await pool.query(
    `UPDATE scheduled_action_runs
        SET status = 'running', started_at = CURRENT_TIMESTAMP
      WHERE id = $1`,
    [runId],
  );
}

/**
 * Mark a run as completed with optional chat identifiers.
 */
export async function markRunCompleted(
  runId: string,
  chatTaskId: string | null,
  chatMessageId: string | null,
): Promise<void> {
  await pool.query(
    `UPDATE scheduled_action_runs
        SET status = 'completed', completed_at = CURRENT_TIMESTAMP,
            chat_task_id = $2, chat_message_id = $3
      WHERE id = $1`,
    [runId, chatTaskId, chatMessageId],
  );
}

/**
 * Mark a run as failed with an error description.
 */
export async function markRunFailed(runId: string, errorText: string): Promise<void> {
  await pool.query(
    `UPDATE scheduled_action_runs
        SET status = 'failed', completed_at = CURRENT_TIMESTAMP, error_text = $2
      WHERE id = $1`,
    [runId, errorText],
  );
}

/**
 * List runs for a specific scheduled action (most recent first).
 */
export async function listScheduledActionRuns(
  userId: string,
  scheduledActionId: string,
  limit = 20,
): Promise<ScheduledActionRun[]> {
  const result = await pool.query<ScheduledActionRunRow>(
    `SELECT ${RUN_SELECT_COLS}
       FROM scheduled_action_runs
      WHERE user_id = $1 AND scheduled_action_id = $2
      ORDER BY scheduled_fire_at DESC
      LIMIT $3`,
    [userId, scheduledActionId, limit],
  );
  return result.rows.map(toRunDto);
}
