import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const runId = requiredEnv('RUN_ID');
const evidenceDir = requiredEnv('EVIDENCE_DIR');
const apiBaseUrl = requiredEnv('BRICKS_API_BASE_URL').replace(/\/$/, '');
const repoRoot = requiredEnv('REPO_ROOT');
const token = requiredEnv('BRICKS_TEST_TOKEN');
const expectedUserId = requiredEnv('FIXTURE_USER_ID');
const caseName = 'thread-auto-name-source';
const backendRequire = createRequire(
  path.join(repoRoot, 'apps/node_backend/package.json'),
);
const { createClient: createLibsqlClient } = backendRequire('@libsql/client');

const fixtureSafeRunId = runId.replace(/[^a-zA-Z0-9-]/g, '-');
const channelId = `e2e-auto-name-${fixtureSafeRunId}`;
const threadId = `thread-${fixtureSafeRunId}`;
const sessionId = `session:${channelId}:${threadId}`;
const firstMessage =
  `thread title smoke test ${fixtureSafeRunId} for automatic naming verification`;
const secondMessage = `second smoke message ${fixtureSafeRunId}`;

const summary = {
  runId,
  caseName,
  apiBaseUrl,
  evidenceDir,
  fixture: {
    channelId,
    threadId,
    sessionId,
    firstMessage,
  },
  checks: {},
  files: {},
  observations: {},
  diagnosis: null,
};

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function artifact(name) {
  return `${fixtureSafeRunId}-${name}`;
}

async function writeJson(name, value) {
  const filePath = path.join(evidenceDir, name);
  await fs.writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
  summary.files[name.replace(/\.json$/, '')] = filePath;
}

async function checkpoint(name, fn) {
  try {
    const value = await fn();
    summary.checks[name] = 'pass';
    await writeJson('summary.json', summary);
    return value;
  } catch (error) {
    summary.checks[name] = 'fail';
    summary.diagnosis = diagnose(name);
    summary.error = {
      check: name,
      message: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    };
    await writeJson('summary.json', summary);
    throw error;
  }
}

function diagnose(check) {
  switch (check) {
    case 'authMe':
      return 'The test token was not accepted by the local API.';
    case 'backendReady':
      return 'The local backend health endpoint is not ready.';
    case 'baselineNoName':
      return 'The fixture Thread already has a name row before the test.';
    case 'firstRespondAccepted':
      return 'The first respond request was not accepted.';
    case 'generatedNameVisible':
      return 'The Thread name did not reach source=first_message_generated.';
    case 'secondRespondAccepted':
      return 'The second respond request was not accepted.';
    case 'generationRunsOnce':
      return 'The second message changed the generated name or attempted timestamp.';
    default:
      return `Checkpoint failed: ${check}`;
  }
}

async function api(pathname, options = {}) {
  const response = await fetch(`${apiBaseUrl}${pathname}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: response.status, body };
}

function createDbClient() {
  const tursoUrl = process.env.TURSO_DATABASE_URL?.trim();
  if (!tursoUrl) {
    throw new Error('This evidence flow requires TURSO_DATABASE_URL for DB checkpoints.');
  }
  return createLibsqlClient({
    url: tursoUrl,
    authToken: process.env.TURSO_AUTH_TOKEN?.trim() || undefined,
  });
}

const db = createDbClient();

async function readThreadNameRow() {
  const result = await db.execute({
    sql:
      `SELECT channel_id, thread_id, display_name, source, generated_name_attempted_at, created_at, updated_at
         FROM chat_channel_names
        WHERE user_id = ?
          AND channel_id = ?
          AND thread_id = ?
        LIMIT 1`,
    args: [expectedUserId, channelId, threadId],
  });
  const row = result.rows[0];
  if (!row) return null;
  return {
    channelId: String(row.channel_id),
    threadId: String(row.thread_id),
    displayName: String(row.display_name),
    source: String(row.source),
    generatedNameAttemptedAt:
      row.generated_name_attempted_at == null
        ? null
        : String(row.generated_name_attempted_at),
    createdAt: row.created_at == null ? null : String(row.created_at),
    updatedAt: row.updated_at == null ? null : String(row.updated_at),
  };
}

async function pollThreadName(predicate, timeoutMs = 120000) {
  const deadline = Date.now() + timeoutMs;
  let last = null;
  while (Date.now() < deadline) {
    last = await readThreadNameRow();
    if (last && predicate(last)) return last;
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  throw new Error(`Timed out waiting for thread name. Last row: ${JSON.stringify(last)}`);
}

async function sendMessage(message, index) {
  return api('/api/chat/respond', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      taskId: `task-${fixtureSafeRunId}-${index}`,
      idempotencyKey: `idem-${fixtureSafeRunId}-${index}`,
      channelId,
      threadId,
      sessionId,
      userMessageId: `msg-u-${fixtureSafeRunId}-${index}`,
      assistantMessageId: `msg-a-${fixtureSafeRunId}-${index}`,
      userMessage: message,
      systemPrompt: 'Reply with exactly "OK". Do not call tools.',
    }),
  });
}

await checkpoint('backendReady', async () => {
  const health = await fetch(`${apiBaseUrl}/api/health`);
  const body = await health.json().catch(() => null);
  await writeJson(artifact('health.json'), { status: health.status, body });
  if (health.status !== 200) throw new Error(`/api/health returned ${health.status}`);
});

await checkpoint('authMe', async () => {
  const result = await api('/api/auth/me');
  await writeJson(artifact('auth-me.json'), result);
  if (result.status !== 200) throw new Error(`/api/auth/me returned ${result.status}`);
  const userId = result.body?.user?.id ?? result.body?.id ?? result.body?.userId;
  if (userId !== expectedUserId) {
    throw new Error(`Expected user ${expectedUserId}, got ${userId}`);
  }
});

await checkpoint('baselineNoName', async () => {
  const existing = await readThreadNameRow();
  await writeJson(artifact('names-before.json'), { row: existing });
  if (existing) throw new Error(`Fixture Thread already had a name: ${JSON.stringify(existing)}`);
});

await checkpoint('firstRespondAccepted', async () => {
  const result = await sendMessage(firstMessage, 1);
  await writeJson(artifact('respond-first.json'), result);
  if (result.status !== 200) throw new Error(`/api/chat/respond returned ${result.status}`);
  if (result.body?.state !== 'accepted') {
    throw new Error(`Expected accepted state, got ${JSON.stringify(result.body)}`);
  }
});

const generatedRow = await checkpoint('generatedNameVisible', async () => {
  const firstObservedRow = await pollThreadName(
    (item) =>
      item.source === 'first_message_exact' ||
      item.source === 'first_message_generated',
    30000,
  );
  await writeJson(artifact('names-after-first-observed.json'), {
    row: firstObservedRow,
  });
  const row = await pollThreadName(
    (item) => item.source === 'first_message_generated',
  );
  await writeJson(artifact('names-after-first.json'), {
    row,
  });
  if (!row.generatedNameAttemptedAt) {
    throw new Error(`generatedNameAttemptedAt was empty: ${JSON.stringify(row)}`);
  }
  if (row.displayName === firstMessage) {
    throw new Error(`Generated name did not differ from exact first message: ${row.displayName}`);
  }
  summary.observations.generatedRow = row;
  return row;
});

await checkpoint('secondRespondAccepted', async () => {
  const result = await sendMessage(secondMessage, 2);
  await writeJson(artifact('respond-second.json'), result);
  if (result.status !== 200) throw new Error(`/api/chat/respond returned ${result.status}`);
  if (result.body?.state !== 'accepted') {
    throw new Error(`Expected accepted state, got ${JSON.stringify(result.body)}`);
  }
});

await checkpoint('generationRunsOnce', async () => {
  await new Promise((resolve) => setTimeout(resolve, 6000));
  const row = await readThreadNameRow();
  await writeJson(artifact('names-after-second.json'), {
    row,
  });
  if (!row) throw new Error('Thread name row disappeared');
  if (row.source !== 'first_message_generated') {
    throw new Error(`Expected generated source, got ${row.source}`);
  }
  if (row.displayName !== generatedRow.displayName) {
    throw new Error(`Name changed after second message: ${row.displayName}`);
  }
  if (row.generatedNameAttemptedAt !== generatedRow.generatedNameAttemptedAt) {
    throw new Error(
      `Attempt timestamp changed after second message: ${row.generatedNameAttemptedAt}`,
    );
  }
  summary.observations.afterSecondRow = row;
});

summary.diagnosis = 'Thread auto naming generated once and stayed stable.';
await writeJson('summary.json', summary);
