import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const env = process.env;
const runnerRequire = createRequire(
  path.join(requiredEnv('HARNESS_RUNNER_DIR'), 'package.json'),
);
const { createClient } = runnerRequire('@libsql/client');
const { chromium } = runnerRequire('playwright');
const evidenceDir = requiredEnv('EVIDENCE_DIR');
const apiBaseUrl = requiredEnv('BRICKS_API_BASE_URL').replace(/\/$/, '');
const webUrl = (env.BRICKS_WEB_URL || 'http://127.0.0.1:8082').replace(/\/$/, '');
const token = requiredEnv('BRICKS_TEST_TOKEN');
const userId = requiredEnv('FIXTURE_USER_ID');
const runId = requiredEnv('RUN_ID');
const channelName = env.CHANNEL_NAME || `E2E New Channel ${runId}`;

const summary = {
  runId,
  channelName,
  apiBaseUrl,
  webUrl,
  evidenceDir,
  checks: {},
  diagnosis: null,
  files: {},
};
let browserEvents = [];

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
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

function diagnose(failedCheck) {
  switch (failedCheck) {
    case 'authMe':
      return 'The injected test token is not accepted by the local API. Check JWT_SECRET, BRICKS_TEST_TOKEN, and FIXTURE_USER_ID.';
    case 'initialAbsent':
      return 'The generated channel name already exists before the test. Use a different RUN_ID or CHANNEL_NAME.';
    case 'uiAfterCreate':
      return 'The New Channel UI failed immediately after submit. Check screenshots and browser-events for Flutter assertions, local state updates, or sidebar props issues.';
    case 'apiAfterCreate':
      return 'The UI flow completed, but /api/chat/channel-names did not return the new name. Likely save request or backend persistence failure.';
    case 'dbAfterCreate':
      return 'The API checkpoint passed, but direct Turso query did not find the row. Check API data source or DB write consistency.';
    case 'uiAfterReopen':
      return 'The channel appeared after creation but disappeared after closing/reopening the sidebar. Likely sidebar rebuild or refresh overwrote local state.';
    case 'uiAfterRefresh':
      return 'The API/DB row exists, but browser refresh did not hydrate the sidebar. Likely startup channel-name hydration or sidebar list assembly failure.';
    default:
      return `Checkpoint failed: ${failedCheck}`;
  }
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

function channelNamesFromApiBody(body) {
  if (!body || !Array.isArray(body.channelNames)) return [];
  return body.channelNames;
}

function containsDisplayName(rows, name) {
  return rows.some((row) => row?.displayName === name || row?.display_name === name);
}

async function queryDbByName(name) {
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
      args: [userId, name],
    });
    return result.rows;
  } finally {
    client.close();
  }
}

async function clickFirstVisible(page, candidates, description) {
  for (const candidate of candidates) {
    const locator =
      candidate.kind === 'role'
        ? page.getByRole(candidate.role, candidate.options)
        : candidate.kind === 'label'
          ? page.getByLabel(candidate.text)
          : page.getByText(candidate.text, candidate.options);
    try {
      await locator.first().waitFor({ state: 'visible', timeout: candidate.timeout ?? 3000 });
      await locator.first().click();
      return;
    } catch {
      // Try the next locator.
    }
  }
  throw new Error(`Could not click ${description}`);
}

async function openSidebar(page) {
  // Flutter web renders this app mostly to canvas in automation, so text
  // locators are not stable. The harness uses a fixed mobile viewport and
  // taps the AppBar menu button by coordinate.
  await page.mouse.click(28, 28);
  await page.waitForTimeout(3000);
}

async function closeSidebar(page) {
  await page.mouse.click(28, 28);
  await page.waitForTimeout(800);
}

async function ensureLoggedIn(page) {
  browserEvents = [];
  page.on('console', (message) => {
    browserEvents.push({
      type: 'console',
      level: message.type(),
      text: message.text(),
    });
  });
  page.on('pageerror', (error) => {
    browserEvents.push({
      type: 'pageerror',
      text: error.message,
      stack: error.stack,
    });
  });
  page.on('requestfailed', (request) => {
    browserEvents.push({
      type: 'requestfailed',
      url: request.url(),
      failure: request.failure()?.errorText,
    });
  });
  summary.browserEvents = browserEvents;

  await page.goto(webUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(6000);
  await page.screenshot({ path: path.join(evidenceDir, '00-login-or-chat.png'), fullPage: true });
  summary.files.loginOrChatScreenshot = path.join(evidenceDir, '00-login-or-chat.png');
  await writeJson('browser-events.json', browserEvents);

  // In the login screen, Quick Login is the middle full-width button.
  // If the user is already logged in, this click lands on empty chat content
  // and is harmless.
  await page.mouse.click(195, 505);
  await page.waitForTimeout(8000);
}

async function expectTextVisible(page, text, timeout = 10000) {
  await page.getByText(text, { exact: true }).first().waitFor({ state: 'visible', timeout });
}

async function createChannelThroughUi(page) {
  // Channels tab action row: New Channel button at the right side.
  await page.mouse.click(305, 130);
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(evidenceDir, '01b-new-channel-dialog.png'), fullPage: true });
  summary.files.newChannelDialogScreenshot = path.join(evidenceDir, '01b-new-channel-dialog.png');
  await page.keyboard.insertText(channelName);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(evidenceDir, '01c-channel-name-entered.png'), fullPage: true });
  summary.files.channelNameEnteredScreenshot = path.join(evidenceDir, '01c-channel-name-entered.png');
  // Dialog confirm button is on the lower-right side. Use a pointer click
  // instead of Enter so the harness follows the user's tap/click flow.
  await page.mouse.click(282, 482);
  await page.waitForTimeout(2500);
}

function recentFlutterAssertion() {
  return browserEvents.some((event) => {
    const text = `${event.text ?? ''} ${event.stack ?? ''}`;
    return text.includes('EXCEPTION CAUGHT BY WIDGETS LIBRARY') ||
      text.includes('Assertion failed') ||
      text.includes('TextEditingController was used after being disposed') ||
      text.includes('Tried to build dirty widget in the wrong build scope');
  });
}

async function main() {
  await fs.mkdir(evidenceDir, { recursive: true });

  const beforeApi = await checkpoint('authMe', async () => {
    const result = await apiGet('/api/auth/me');
    await writeJson('auth-me.json', result);
    if (result.status !== 200) {
      throw new Error(`/api/auth/me returned ${result.status}`);
    }
    return result;
  });
  void beforeApi;

  const apiBefore = await checkpoint('initialAbsent', async () => {
    const result = await apiGet('/api/chat/channel-names');
    await writeJson('api-before.json', result);
    if (result.status !== 200) {
      throw new Error(`/api/chat/channel-names returned ${result.status}`);
    }
    if (containsDisplayName(channelNamesFromApiBody(result.body), channelName)) {
      throw new Error(`Channel name already exists: ${channelName}`);
    }
    const dbRows = await queryDbByName(channelName);
    await writeJson('db-before.json', dbRows);
    if (containsDisplayName(dbRows, channelName)) {
      throw new Error(`DB row already exists: ${channelName}`);
    }
    return result;
  });
  void apiBefore;

  const browser = await chromium.launch({ headless: env.HEADFUL === '1' ? false : true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  try {
    await ensureLoggedIn(page);
    await openSidebar(page);
    await page.screenshot({ path: path.join(evidenceDir, '01-initial-sidebar.png'), fullPage: true });
    summary.files.initialSidebarScreenshot = path.join(evidenceDir, '01-initial-sidebar.png');

    await createChannelThroughUi(page);

    await checkpoint('uiAfterCreate', async () => {
      await openSidebar(page);
      await page.screenshot({ path: path.join(evidenceDir, '02-after-create-sidebar.png'), fullPage: true });
      summary.files.afterCreateSidebarScreenshot = path.join(evidenceDir, '02-after-create-sidebar.png');
      if (recentFlutterAssertion()) {
        await writeJson('browser-events.json', browserEvents);
        throw new Error('Flutter reported an assertion during the New Channel UI flow.');
      }
    });

    await checkpoint('apiAfterCreate', async () => {
      const deadline = Date.now() + 10000;
      let latest;
      while (Date.now() < deadline) {
        latest = await apiGet('/api/chat/channel-names');
        if (latest.status === 200 && containsDisplayName(channelNamesFromApiBody(latest.body), channelName)) {
          await writeJson('api-after-create.json', latest);
          return latest;
        }
        await page.waitForTimeout(500);
      }
      await writeJson('api-after-create.json', latest ?? null);
      throw new Error(`API did not return created channel: ${channelName}`);
    });

    await checkpoint('dbAfterCreate', async () => {
      const deadline = Date.now() + 10000;
      let rows = [];
      while (Date.now() < deadline) {
        rows = await queryDbByName(channelName);
        if (containsDisplayName(rows, channelName)) {
          await writeJson('db-after-create.json', rows);
          return rows;
        }
        await page.waitForTimeout(500);
      }
      await writeJson('db-after-create.json', rows);
      throw new Error(`DB did not contain created channel: ${channelName}`);
    });

    await checkpoint('uiAfterReopen', async () => {
      await closeSidebar(page);
      await openSidebar(page);
      await page.screenshot({ path: path.join(evidenceDir, '02b-after-reopen-sidebar.png'), fullPage: true });
      summary.files.afterReopenSidebarScreenshot = path.join(evidenceDir, '02b-after-reopen-sidebar.png');
    });

    await checkpoint('uiAfterRefresh', async () => {
      await page.reload({ waitUntil: 'domcontentloaded' });
      await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
      await page.waitForTimeout(6000);
      await page.mouse.click(195, 505);
      await page.waitForTimeout(2500);
      await openSidebar(page);
      await page.screenshot({ path: path.join(evidenceDir, '03-after-refresh-sidebar.png'), fullPage: true });
      summary.files.afterRefreshSidebarScreenshot = path.join(evidenceDir, '03-after-refresh-sidebar.png');
    });

    summary.diagnosis = 'All checkpoints passed.';
    await writeJson('summary.json', summary);
  } finally {
    if (summary.error) {
      await page.screenshot({ path: path.join(evidenceDir, 'failure.png'), fullPage: true }).catch(() => {});
      summary.files.failureScreenshot = path.join(evidenceDir, 'failure.png');
      await writeJson('summary.json', summary).catch(() => {});
    }
    await context.close().catch(() => {});
    await browser.close().catch(() => {});
  }
}

main().catch(async (error) => {
  console.error(error);
  process.exitCode = 1;
});
