const fs = require('fs');
const path = require('path');

const SCREENSHOT_DIR = 'screenshots';
const SCREENSHOT_FILE = 'home.png';
const COMMENT_MARKER = '<!-- pr-homepage-screenshot-bot -->';
const PREVIEW_BRANCH = 'pr-screenshot-previews';
const PREVIEW_ROOT = '.github/pr-screenshots';
const NOT_FOUND_MESSAGE = 'Not Found';
const MAX_COMMENT_PAGES = 10;

const token = process.env.GITHUB_TOKEN;
const repository = process.env.GITHUB_REPOSITORY;
const runId = process.env.GITHUB_RUN_ID;
const sha = process.env.GITHUB_SHA;
const prNumber = process.env.PR_NUMBER;
const prHeadRef = process.env.PR_HEAD_REF;

if (!token) throw new Error('GITHUB_TOKEN is required.');
if (!repository || !prNumber || !runId || !prHeadRef || !sha) {
  throw new Error('Missing one or more required GitHub environment variables.');
}

const [owner, repo] = repository.split('/');
if (!owner || !repo) throw new Error(`Invalid GITHUB_REPOSITORY value: ${repository}`);

const previewDir = `${PREVIEW_ROOT}/pr-${prNumber}`;
const screenshotPath = path.join(SCREENSHOT_DIR, SCREENSHOT_FILE);

if (!fs.existsSync(screenshotPath)) {
  throw new Error(`Screenshot file not found: ${screenshotPath}`);
}

function encodedPath(fullPath) {
  return fullPath
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

function previewImageUrl() {
  return `https://raw.githubusercontent.com/${owner}/${repo}/${PREVIEW_BRANCH}/${encodedPath(
    `${previewDir}/${SCREENSHOT_FILE}`,
  )}?v=${encodeURIComponent(sha)}`;
}

async function githubRequest(apiPath, options = {}) {
  const response = await fetch(`https://api.github.com${apiPath}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'bricks-pr-homepage-screenshot-bot',
      ...(options.headers || {}),
    },
  });

  if (response.status === 204) return null;

  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }
  }

  if (!response.ok) {
    const apiMessage = data?.message ? ` - ${data.message}` : text ? ` - ${text}` : '';
    const error = new Error(
      `GitHub API ${options.method || 'GET'} ${apiPath} failed: ${response.status}${apiMessage}`,
    );
    error.response = data !== null ? data : text;
    error.status = response.status;
    throw error;
  }

  return data !== null ? data : text || null;
}

async function ensurePreviewBranch() {
  try {
    await githubRequest(`/repos/${owner}/${repo}/git/ref/heads/${PREVIEW_BRANCH}`);
  } catch (error) {
    if (error.response?.message !== NOT_FOUND_MESSAGE) throw error;

    const repoInfo = await githubRequest(`/repos/${owner}/${repo}`);
    const defaultRef = await githubRequest(
      `/repos/${owner}/${repo}/git/ref/heads/${repoInfo.default_branch}`,
    );

    await githubRequest(`/repos/${owner}/${repo}/git/refs`, {
      method: 'POST',
      body: JSON.stringify({
        ref: `refs/heads/${PREVIEW_BRANCH}`,
        sha: defaultRef.object.sha,
      }),
    });
  }
}

async function getExistingPreviewFileSha() {
  try {
    const data = await githubRequest(
      `/repos/${owner}/${repo}/contents/${encodedPath(`${previewDir}/${SCREENSHOT_FILE}`)}?ref=${encodeURIComponent(PREVIEW_BRANCH)}`,
    );
    return data.sha;
  } catch (error) {
    if (error.response?.message === NOT_FOUND_MESSAGE) return undefined;
    throw error;
  }
}

async function uploadPreviewImage(existingSha) {
  const content = fs.readFileSync(screenshotPath).toString('base64');
  const maxRetries = 3;
  let currentSha = existingSha;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      await githubRequest(`/repos/${owner}/${repo}/contents/${encodedPath(`${previewDir}/${SCREENSHOT_FILE}`)}`, {
        method: 'PUT',
        body: JSON.stringify({
          message: `chore: update homepage screenshot preview for PR #${prNumber}`,
          branch: PREVIEW_BRANCH,
          content,
          sha: currentSha,
        }),
      });
      return;
    } catch (error) {
      if (error.status === 409 && attempt < maxRetries) {
        currentSha = await getExistingPreviewFileSha();
        continue;
      }
      throw error;
    }
  }
}

async function upsertPrComment(body) {
  let existing = null;
  let page = 1;

  while (!existing && page <= MAX_COMMENT_PAGES) {
    const comments = await githubRequest(
      `/repos/${owner}/${repo}/issues/${prNumber}/comments?per_page=100&page=${page}`,
    );

    if (!comments.length) break;

    existing = comments.find((comment) => comment.body?.includes(COMMENT_MARKER));

    page += 1;
  }

  if (existing) {
    await githubRequest(`/repos/${owner}/${repo}/issues/comments/${existing.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ body }),
    });
    return;
  }

  await githubRequest(`/repos/${owner}/${repo}/issues/${prNumber}/comments`, {
    method: 'POST',
    body: JSON.stringify({ body }),
  });
}

function buildCommentBody() {
  const artifactUrl = `https://github.com/${owner}/${repo}/actions/runs/${runId}`;

  return [
    '## 🧪 Frontend homepage E2E + screenshot',
    '',
    '### Automated E2E flow',
    '1. Build Flutter web app.',
    '2. Start local static server for the build output.',
    '3. Open homepage in Playwright Chromium.',
    '4. Validate homepage render root exists.',
    '5. Capture homepage screenshot and upload artifact.',
    '',
    `Branch: \`${prHeadRef}\``,
    `Commit: \`${sha.slice(0, 7)}\``,
    `Time: ${new Date().toISOString().replace('T', ' ').slice(0, 19)} UTC`,
    '',
    '### Homepage screenshot',
    `<img src="${previewImageUrl()}" alt="Homepage screenshot" width="720" />`,
    '',
    `👉 [Download workflow artifacts](${artifactUrl})`,
    '',
    COMMENT_MARKER,
  ].join('\n');
}

async function main() {
  await ensurePreviewBranch();
  const existingSha = await getExistingPreviewFileSha();
  await uploadPreviewImage(existingSha);
  await upsertPrComment(buildCommentBody());
}

main().catch((error) => {
  console.error('Error:', error.message);
  if (error.stack) console.error(error.stack);
  if (error.response) console.error(JSON.stringify(error.response, null, 2));
  process.exit(1);
});
