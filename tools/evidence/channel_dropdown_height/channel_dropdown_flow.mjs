import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const env = process.env;
const runnerRequire = createRequire(
  path.join(requiredEnv('HARNESS_RUNNER_DIR'), 'package.json'),
);
const { chromium } = runnerRequire('playwright');
const { PNG } = runnerRequire('pngjs');

const runId = requiredEnv('RUN_ID');
const evidenceDir = requiredEnv('EVIDENCE_DIR');
const apiBaseUrl = requiredEnv('BRICKS_API_BASE_URL').replace(/\/$/, '');
const webUrl = (env.BRICKS_WEB_URL || 'http://127.0.0.1:8082').replace(/\/$/, '');
const token = requiredEnv('BRICKS_TEST_TOKEN');
const minChannelCount = Number(env.MIN_CHANNEL_DROPDOWN_COUNT || 28);
const maxMenuHeight = Number(env.MAX_CHANNEL_MENU_HEIGHT || 460);
const caseName = 'channel-dropdown-height';
const fixturePrefix = `E2E Dropdown ${runId}`;

const summary = {
  runId,
  caseName,
  apiBaseUrl,
  webUrl,
  evidenceDir,
  minChannelCount,
  maxMenuHeight,
  checks: {},
  files: {},
  measurements: {},
  diagnosis: null,
};

const browserEvents = [];

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function artifact(name) {
  return `${runId}-${name}`;
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
    case 'fixtureReady':
      return 'The fixture user does not have enough channel names and the harness could not create them.';
    case 'menuOpened':
      return 'Clicking the active channel label did not produce a detectable popup region.';
    case 'menuHeightBounded':
      return 'The detected popup region exceeds the allowed height.';
    case 'menuScrollsInternally':
      return 'Wheel scrolling did not produce a meaningful visual change inside the popup.';
    case 'noBrowserErrors':
      return 'Browser console, pageerror, or requestfailed events include an error-level signal.';
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

function channelNamesFrom(body) {
  return Array.isArray(body?.channelNames) ? body.channelNames : [];
}

async function ensureEnoughChannels() {
  const before = await api('/api/chat/channel-names');
  await writeJson('api-channel-names-before.json', {
    status: before.status,
    count: channelNamesFrom(before.body).length,
  });
  if (before.status !== 200) {
    throw new Error(`/api/chat/channel-names returned ${before.status}`);
  }

  let count = channelNamesFrom(before.body).length;
  const created = [];
  for (let i = count; i < minChannelCount; i += 1) {
    const displayName = `${fixturePrefix}-${String(i + 1).padStart(2, '0')}`;
    const channelId = `e2e-dropdown-${runId}-${i + 1}`;
    const result = await api('/api/chat/channel-names', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ channelId, displayName }),
    });
    if (result.status !== 200) {
      throw new Error(`Failed to create fixture channel ${displayName}: ${result.status}`);
    }
    created.push({ channelId, displayName });
    count += 1;
  }

  const after = await api('/api/chat/channel-names');
  const afterCount = channelNamesFrom(after.body).length;
  await writeJson('api-channel-names-after-fixture.json', {
    status: after.status,
    beforeCount: channelNamesFrom(before.body).length,
    afterCount,
    created,
  });
  if (after.status !== 200 || afterCount < minChannelCount) {
    throw new Error(`Expected at least ${minChannelCount} channels, got ${afterCount}`);
  }
  summary.measurements.channelCount = afterCount;
  summary.measurements.createdChannelCount = created.length;
}

async function ensureLoggedIn(page) {
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

  await page.goto(webUrl, { waitUntil: 'domcontentloaded' });
  await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(6000);
  const loginPath = path.join(evidenceDir, artifact('00-login-or-chat.png'));
  await page.screenshot({ path: loginPath, fullPage: true });
  summary.files.loginOrChatScreenshot = loginPath;
  await page.mouse.click(195, 505);
  await page.waitForTimeout(8000);
}

async function screenshot(page, name) {
  const filePath = path.join(evidenceDir, artifact(name));
  await page.screenshot({ path: filePath, fullPage: true });
  summary.files[name.replace(/\.png$/, '').replaceAll('-', '_')] = filePath;
  return filePath;
}

async function readPng(filePath) {
  const buffer = await fs.readFile(filePath);
  return PNG.sync.read(buffer);
}

function diffBounds(before, after, threshold = 45) {
  if (before.width !== after.width || before.height !== after.height) {
    throw new Error('Screenshots have different dimensions.');
  }
  let minX = before.width;
  let minY = before.height;
  let maxX = -1;
  let maxY = -1;
  let changed = 0;
  for (let y = 0; y < before.height; y += 1) {
    for (let x = 0; x < before.width; x += 1) {
      const idx = (before.width * y + x) << 2;
      const delta =
        Math.abs(before.data[idx] - after.data[idx]) +
        Math.abs(before.data[idx + 1] - after.data[idx + 1]) +
        Math.abs(before.data[idx + 2] - after.data[idx + 2]);
      if (delta > threshold) {
        changed += 1;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < minX || maxY < minY) return null;
  return {
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
    changed,
  };
}

function countChangedInside(a, b, bounds, threshold = 45) {
  let changed = 0;
  const xStart = Math.max(0, bounds.x);
  const yStart = Math.max(0, bounds.y);
  const xEnd = Math.min(a.width, bounds.x + bounds.width);
  const yEnd = Math.min(a.height, bounds.y + bounds.height);
  for (let y = yStart; y < yEnd; y += 1) {
    for (let x = xStart; x < xEnd; x += 1) {
      const idx = (a.width * y + x) << 2;
      const delta =
        Math.abs(a.data[idx] - b.data[idx]) +
        Math.abs(a.data[idx + 1] - b.data[idx + 1]) +
        Math.abs(a.data[idx + 2] - b.data[idx + 2]);
      if (delta > threshold) changed += 1;
    }
  }
  return changed;
}

function significantBrowserErrors() {
  return browserEvents.filter((event) => {
    const text = `${event.text ?? ''} ${event.failure ?? ''} ${event.stack ?? ''}`;
    if (event.type === 'pageerror') return true;
    if (event.type === 'requestfailed' && !text.includes('net::ERR_ABORTED')) return true;
    return text.includes('EXCEPTION CAUGHT BY WIDGETS LIBRARY') ||
      text.includes('Assertion failed') ||
      text.includes('RenderFlex overflowed');
  });
}

async function main() {
  await fs.mkdir(evidenceDir, { recursive: true });

  await checkpoint('authMe', async () => {
    const result = await api('/api/auth/me');
    await writeJson('auth-me.json', result);
    if (result.status !== 200) throw new Error(`/api/auth/me returned ${result.status}`);
  });

  await checkpoint('fixtureReady', ensureEnoughChannels);

  const browser = await chromium.launch({ headless: env.HEADFUL === '1' ? false : true });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  try {
    await ensureLoggedIn(page);
    const beforePath = await screenshot(page, '01-before-menu.png');
    await page.mouse.click(138, 28);
    await page.waitForTimeout(1200);
    const openPath = await screenshot(page, '02-menu-open.png');

    const beforePng = await readPng(beforePath);
    const openPng = await readPng(openPath);
    const popupBounds = await checkpoint('menuOpened', async () => {
      const bounds = diffBounds(beforePng, openPng);
      if (!bounds || bounds.changed < 2000) {
        throw new Error(`Could not detect popup bounds; changed=${bounds?.changed ?? 0}`);
      }
      summary.measurements.popupBounds = bounds;
      return bounds;
    });

    await checkpoint('menuHeightBounded', async () => {
      if (popupBounds.height > maxMenuHeight) {
        throw new Error(`Popup height ${popupBounds.height} exceeds ${maxMenuHeight}`);
      }
      summary.measurements.popupHeight = popupBounds.height;
      summary.measurements.viewportHeight = openPng.height;
    });

    await page.mouse.move(
      popupBounds.x + Math.min(120, Math.floor(popupBounds.width / 2)),
      popupBounds.y + Math.min(popupBounds.height - 20, Math.floor(popupBounds.height / 2)),
    );
    await page.mouse.wheel(0, 1200);
    await page.waitForTimeout(700);
    const scrolledPath = await screenshot(page, '03-menu-scrolled.png');
    const scrolledPng = await readPng(scrolledPath);

    await checkpoint('menuScrollsInternally', async () => {
      const changedInside = countChangedInside(openPng, scrolledPng, popupBounds);
      summary.measurements.changedPixelsInsidePopupAfterWheel = changedInside;
      if (changedInside < 700) {
        throw new Error(`Expected visible menu content to change after wheel, got ${changedInside} changed pixels.`);
      }
    });

    await writeJson('browser-events.json', browserEvents);
    await checkpoint('noBrowserErrors', async () => {
      const errors = significantBrowserErrors();
      summary.measurements.browserErrorCount = errors.length;
      if (errors.length > 0) {
        await writeJson('browser-errors.json', errors);
        throw new Error(`Captured ${errors.length} browser errors.`);
      }
    });

    summary.diagnosis = 'All checkpoints passed.';
    await writeJson('summary.json', summary);
  } finally {
    await writeJson('browser-events.json', browserEvents).catch(() => {});
    await context.close().catch(() => {});
    await browser.close().catch(() => {});
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
