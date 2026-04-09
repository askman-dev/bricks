const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE_URL = process.env.E2E_BASE_URL || 'http://127.0.0.1:4173';
const OUTPUT_DIR = 'screenshots';
const OUTPUT_FILE = 'chat-after-login.png';

function logStep(step, message) {
  console.log(`E2E FLOW ${step}: ${message}`);
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  logStep('1/7', 'Launch Chromium browser');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  logStep('2/7', `Open login page ${BASE_URL}`);
  await page.goto(BASE_URL, { waitUntil: 'networkidle' });

  logStep('3/7', 'Ensure GitHub login entry is visible');
  const loginLink = page.getByRole('link', { name: 'Login with GitHub' });
  await loginLink.waitFor({ state: 'visible' });

  logStep('4/7', 'Click login entry and follow backend auth redirect flow');
  await Promise.all([
    page.waitForURL('**/chat', { timeout: 45_000 }),
    loginLink.click(),
  ]);

  logStep('5/7', 'Validate chat page rendered after login');
  await page.getByPlaceholder('Ask Bricks to create something...').waitFor({ state: 'visible' });
  await page.getByRole('article', { name: 'message-list' }).waitFor({ state: 'visible' });

  logStep('6/7', 'Verify URL path confirms navigation to /chat');
  const currentUrl = new URL(page.url());
  if (currentUrl.pathname !== '/chat') {
    throw new Error(`Expected /chat after login, got ${currentUrl.pathname}`);
  }

  logStep('7/7', `Capture screenshot to ${path.join(OUTPUT_DIR, OUTPUT_FILE)}`);
  await page.screenshot({
    path: path.join(OUTPUT_DIR, OUTPUT_FILE),
    fullPage: true,
  });

  await browser.close();
  console.log('E2E RESULT: Login flow and chat-page navigation passed.');
}

main().catch((error) => {
  console.error('E2E RESULT: Login flow and chat-page navigation failed.');
  console.error(error);
  process.exit(1);
});
