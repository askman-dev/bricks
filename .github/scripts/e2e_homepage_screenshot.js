const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const BASE_URL = process.env.E2E_BASE_URL || 'http://127.0.0.1:4173';
const OUTPUT_DIR = 'screenshots';
const OUTPUT_FILE = 'home.png';
const FLUTTER_WAIT_MS = 4000;

function logStep(step, message) {
  console.log(`E2E FLOW ${step}: ${message}`);
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  logStep('1/5', 'Launch Chromium browser');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });

  logStep('2/5', `Open homepage ${BASE_URL}`);
  await page.goto(BASE_URL, { waitUntil: 'networkidle' });

  logStep('3/5', 'Wait for Flutter semantic tree to be stable');
  await page.waitForTimeout(FLUTTER_WAIT_MS);

  logStep('4/5', 'Validate homepage main rendering element exists');
  const hasFlutterRoot =
    (await page.locator('flt-glass-pane').count()) > 0 ||
    (await page.locator('flt-scene-host').count()) > 0 ||
    (await page.locator('canvas').count()) > 0;

  if (!hasFlutterRoot) {
    throw new Error('Homepage render check failed: no Flutter root element detected.');
  }

  logStep('5/5', `Capture screenshot to ${path.join(OUTPUT_DIR, OUTPUT_FILE)}`);
  await page.screenshot({
    path: path.join(OUTPUT_DIR, OUTPUT_FILE),
    fullPage: true,
  });

  await browser.close();
  console.log('E2E RESULT: Homepage smoke test passed.');
}

main().catch((error) => {
  console.error('E2E RESULT: Homepage smoke test failed.');
  console.error(error);
  process.exit(1);
});
