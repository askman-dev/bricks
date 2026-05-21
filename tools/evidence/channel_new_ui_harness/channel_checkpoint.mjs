import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const env = process.env;
const mode = process.argv[2] ?? 'after';
const evidenceDir = requiredEnv('EVIDENCE_DIR');
const channelName = requiredEnv('CHANNEL_NAME');
const apiBaseUrl = requiredEnv('BRICKS_API_BASE_URL').replace(/\/$/, '');
const token = requiredEnv('BRICKS_TEST_TOKEN');
const userId = requiredEnv('FIXTURE_USER_ID');
const runnerRequire = createRequire(
  path.join(requiredEnv('HARNESS_RUNNER_DIR'), 'package.json'),
);
const { createClient } = runnerRequire('@libsql/client');

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

async function readSummary() {
  try {
    return JSON.parse(await fs.readFile(path.join(evidenceDir, 'summary.json'), 'utf8'));
  } catch {
    return {
      runId: requiredEnv('RUN_ID'),
      channelName,
      apiBaseUrl,
      evidenceDir,
      checks: {},
      files: {},
    };
  }
}

async function writeJson(name, value) {
  await fs.writeFile(path.join(evidenceDir, name), `${JSON.stringify(value, null, 2)}\n`);
}

function containsName(items) {
  return items.some((item) => item?.displayName === channelName || item?.display_name === channelName);
}

async function apiGet(pathname) {
  const response = await fetch(`${apiBaseUrl}${pathname}`, {
    headers: { Authorization: `Bearer ${token}` },
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

async function queryDb() {
  const client = createClient({
    url: requiredEnv('TURSO_DATABASE_URL'),
    authToken: env.TURSO_AUTH_TOKEN?.trim(),
  });
  try {
    const result = await client.execute({
      sql: `
        SELECT user_id, channel_id, thread_id, display_name, created_at, updated_at
          FROM chat_channel_names
         WHERE user_id = ?
           AND display_name = ?
         ORDER BY updated_at DESC
         LIMIT 5
      `,
      args: [userId, channelName],
    });
    return result.rows;
  } finally {
    client.close();
  }
}

async function main() {
  await fs.mkdir(evidenceDir, { recursive: true });
  const summary = await readSummary();

  const authMe = await apiGet('/api/auth/me');
  await writeJson(`auth-me-${mode}.json`, authMe);
  if (authMe.status !== 200) {
    summary.checks.authMe = 'fail';
    summary.diagnosis = 'The injected test token is not accepted by the local API.';
    await writeJson('summary.json', summary);
    throw new Error(`/api/auth/me returned ${authMe.status}`);
  }
  summary.checks.authMe = 'pass';

  const api = await apiGet('/api/chat/channel-names');
  const dbRows = await queryDb();
  await writeJson(`api-${mode}.json`, api);
  await writeJson(`db-${mode}.json`, dbRows);

  if (api.status !== 200) {
    summary.checks[`${mode}ApiReachable`] = 'fail';
    summary.diagnosis = `/api/chat/channel-names returned ${api.status}.`;
    await writeJson('summary.json', summary);
    throw new Error(summary.diagnosis);
  }

  const apiNames = Array.isArray(api.body?.channelNames) ? api.body.channelNames : [];
  const apiHasName = containsName(apiNames);
  const dbHasName = containsName(dbRows);

  if (mode === 'before') {
    summary.checks.initialAbsent = apiHasName || dbHasName ? 'fail' : 'pass';
    if (summary.checks.initialAbsent === 'fail') {
      summary.diagnosis = 'The generated channel name already exists before the test.';
      await writeJson('summary.json', summary);
      throw new Error(summary.diagnosis);
    }
  } else {
    summary.checks.apiAfterCreate = apiHasName ? 'pass' : 'fail';
    summary.checks.dbAfterCreate = dbHasName ? 'pass' : 'fail';
    if (!apiHasName) {
      summary.diagnosis = 'The UI flow completed, but /api/chat/channel-names did not return the new name.';
      await writeJson('summary.json', summary);
      throw new Error(summary.diagnosis);
    }
    if (!dbHasName) {
      summary.diagnosis = 'The API checkpoint passed, but direct Turso query did not find the row.';
      await writeJson('summary.json', summary);
      throw new Error(summary.diagnosis);
    }
  }

  await writeJson('summary.json', summary);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
