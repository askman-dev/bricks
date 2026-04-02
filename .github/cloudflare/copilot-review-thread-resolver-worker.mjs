/**
 * Cloudflare Worker: auto-resolve outdated GitHub PR review threads after
 * copilot-swe-agent[bot] posts a PR comment.
 *
 * Copy this file into a Cloudflare Worker project and configure these secrets:
 * - GITHUB_WEBHOOK_SECRET
 *
 * Choose one authentication mode:
 *
 * GitHub App mode:
 * - GITHUB_APP_ID
 * - GITHUB_APP_PRIVATE_KEY
 *
 * Personal token mode:
 * - GITHUB_TOKEN (or GH_TOKEN)
 *
 * Optional variables:
 * - GITHUB_API_URL=https://api.github.com
 * - COPILOT_SWE_AGENT_USER_ID=198982749
 * - COPILOT_SWE_AGENT_APP_URL=https://github.com/apps/copilot-swe-agent
 * - POST_SUMMARY_FOR_ZERO=false
 *
 * GitHub App permissions:
 * - Metadata: Read
 * - Pull requests: Write
 * - Issues: Write
 *
 * GitHub App webhook subscriptions:
 * - Issue comment
 */

const DEFAULT_GITHUB_API_URL = 'https://api.github.com';
const DEFAULT_COPILOT_SWE_AGENT_USER_ID = 198982749;
const DEFAULT_COPILOT_SWE_AGENT_APP_URL = 'https://github.com/apps/copilot-swe-agent';

const QUERY_REVIEW_THREADS = `
  query($owner:String!, $repo:String!, $pr:Int!, $cursor:String) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100, after:$cursor) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            isResolved
            isOutdated
            comments(first:1) {
              nodes {
                url
                author {
                  login
                }
              }
            }
          }
        }
      }
    }
  }
`;

const MUTATION_RESOLVE_THREAD = `
  mutation($threadId:ID!) {
    resolveReviewThread(input:{threadId:$threadId}) {
      thread {
        id
        isResolved
        isOutdated
      }
    }
  }
`;

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);

      if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/healthz')) {
        return jsonResponse({
          ok: true,
          service: 'copilot-review-thread-resolver-worker',
        });
      }

      if (
        request.method === 'POST' &&
        (url.pathname === '/' || url.pathname === '/github/webhook')
      ) {
        return handleWebhook(request, env);
      }

      return jsonResponse({ ok: false, error: 'Not found' }, 404);
    } catch (error) {
      return jsonResponse(
        {
          ok: false,
          error: stringifyError(error),
        },
        500,
      );
    }
  },
};

async function handleWebhook(request, env) {
  assertRequiredEnv(env);

  const signature = request.headers.get('X-Hub-Signature-256');
  const eventName = request.headers.get('X-GitHub-Event') ?? 'unknown';
  const deliveryId = request.headers.get('X-GitHub-Delivery') ?? 'unknown';
  const rawBody = await request.text();

  if (!(await verifyWebhookSignature(rawBody, signature, env.GITHUB_WEBHOOK_SECRET))) {
    return jsonResponse({ ok: false, error: 'Invalid webhook signature' }, 401);
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch (error) {
    return jsonResponse(
      { ok: false, error: `Invalid JSON payload: ${stringifyError(error)}` },
      400,
    );
  }

  if (eventName === 'ping') {
    return jsonResponse({
      ok: true,
      deliveryId,
      event: eventName,
      zen: payload.zen ?? null,
    });
  }

  if (eventName !== 'issue_comment') {
    return jsonResponse({
      ok: true,
      deliveryId,
      event: eventName,
      ignored: 'unsupported_event',
    });
  }

  if (payload.action !== 'created') {
    return jsonResponse({
      ok: true,
      deliveryId,
      event: eventName,
      ignored: 'issue_comment_action_not_created',
      action: payload.action ?? null,
    });
  }

  if (!payload.issue?.pull_request) {
    return jsonResponse({
      ok: true,
      deliveryId,
      event: eventName,
      ignored: 'comment_not_on_pull_request',
    });
  }

  if (!isCopilotSweAgentComment(payload, env)) {
    return jsonResponse({
      ok: true,
      deliveryId,
      event: eventName,
      ignored: 'comment_not_from_copilot_swe_agent',
      commenter: payload.comment?.user?.login ?? null,
    });
  }

  const result = await resolveOutdatedThreads(payload, env);
  return jsonResponse({
    ok: true,
    deliveryId,
    event: eventName,
    ...result,
  });
}

async function resolveOutdatedThreads(payload, env) {
  const owner = payload.repository?.owner?.login;
  const repo = payload.repository?.name;
  const pullNumber = payload.issue?.number;
  if (!owner || !repo || !pullNumber) {
    throw new Error('Missing repository owner/name or pull request number in payload.');
  }

  const githubToken = await getGitHubApiToken(payload, env);
  const threads = await fetchAllReviewThreads({
    owner,
    repo,
    pullNumber,
    token: githubToken,
    apiUrl: env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL,
  });

  const selectedThreads = threads.filter((thread) => thread.isOutdated && !thread.isResolved);
  const resolvedUrls = [];

  for (const thread of selectedThreads) {
    await resolveReviewThread({
      threadId: thread.id,
      token: githubToken,
      apiUrl: env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL,
    });

    const url = thread.comments?.nodes?.[0]?.url;
    if (url) {
      resolvedUrls.push(url);
    }
  }

  if (selectedThreads.length > 0 || parseBoolean(env.POST_SUMMARY_FOR_ZERO, false)) {
    await postSummaryComment({
      owner,
      repo,
      pullNumber,
      token: githubToken,
      triggerCommentUrl: payload.comment?.html_url ?? null,
      triggerCommenter: payload.comment?.user?.login ?? null,
      resolvedCount: selectedThreads.length,
      resolvedUrls,
      apiUrl: env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL,
    });
  }

  return {
    repository: `${owner}/${repo}`,
    pullNumber,
    totalThreads: threads.length,
    selectedThreads: selectedThreads.length,
    resolvedThreads: selectedThreads.length,
  };
}

function isCopilotSweAgentComment(payload, env) {
  const commentUser = payload.comment?.user ?? {};
  const sender = payload.sender ?? {};
  const performedViaApp = payload.comment?.performed_via_github_app ?? null;

  const expectedUserId = Number(
    env.COPILOT_SWE_AGENT_USER_ID || DEFAULT_COPILOT_SWE_AGENT_USER_ID,
  );
  const expectedAppUrl = env.COPILOT_SWE_AGENT_APP_URL || DEFAULT_COPILOT_SWE_AGENT_APP_URL;

  const viaAppSlug =
    performedViaApp?.slug ??
    performedViaApp?.name ??
    (typeof performedViaApp?.html_url === 'string'
      ? performedViaApp.html_url.split('/').pop()
      : null);

  if (viaAppSlug === 'copilot-swe-agent') {
    return true;
  }

  const usersToCheck = [commentUser, sender];
  return usersToCheck.some(
    (user) =>
      user?.type === 'Bot' &&
      (user.id === expectedUserId ||
        user.html_url === expectedAppUrl ||
        user.html_url === `${expectedAppUrl}/`),
  );
}

async function fetchAllReviewThreads({ owner, repo, pullNumber, token, apiUrl }) {
  const threads = [];
  let cursor = null;

  while (true) {
    const response = await githubGraphql({
      token,
      apiUrl,
      query: QUERY_REVIEW_THREADS,
      variables: {
        owner,
        repo,
        pr: pullNumber,
        cursor,
      },
    });

    const pullRequest = response?.data?.repository?.pullRequest;
    if (!pullRequest) {
      throw new Error(`Pull request not found: ${owner}/${repo}#${pullNumber}`);
    }

    const reviewThreads = pullRequest.reviewThreads;
    threads.push(...(reviewThreads.nodes || []));

    if (!reviewThreads.pageInfo?.hasNextPage) {
      break;
    }

    cursor = reviewThreads.pageInfo.endCursor;
  }

  return threads;
}

async function resolveReviewThread({ threadId, token, apiUrl }) {
  await githubGraphql({
    token,
    apiUrl,
    query: MUTATION_RESOLVE_THREAD,
    variables: { threadId },
  });
}

async function postSummaryComment({
  owner,
  repo,
  pullNumber,
  token,
  triggerCommentUrl,
  triggerCommenter,
  resolvedCount,
  resolvedUrls,
  apiUrl,
}) {
  const lines = [];
  lines.push('✅ PR review thread auto resolver completed successfully.');
  lines.push('');

  if (resolvedCount === 0) {
    lines.push('No outdated review thread needed resolving for this Copilot run.');
  } else {
    lines.push(
      `This automation resolved **${resolvedCount}** outdated review thread(s) via the GitHub App webhook worker.`,
    );
    lines.push(
      'The resolved status for the thread(s) listed below was set by automation, not manually by a human reviewer.',
    );
  }

  if (triggerCommentUrl && triggerCommenter) {
    lines.push('');
    lines.push(`> Triggered by: ${triggerCommentUrl}`);
    lines.push(`> Thank you, @${triggerCommenter}! 🙏`);
  }

  if (resolvedUrls.length > 0) {
    lines.push('');
    lines.push('Resolved thread comment links:');
    for (const url of resolvedUrls) {
      lines.push(`- ${url}`);
    }
  }

  await githubRest({
    token,
    apiUrl,
    method: 'POST',
    path: `/repos/${owner}/${repo}/issues/${pullNumber}/comments`,
    body: {
      body: lines.join('\n'),
    },
  });
}

async function createInstallationToken(installationId, env) {
  const apiUrl = env.GITHUB_API_URL || DEFAULT_GITHUB_API_URL;
  const appJwt = await createAppJwt(env.GITHUB_APP_ID, env.GITHUB_APP_PRIVATE_KEY);

  const response = await fetch(`${apiUrl}/app/installations/${installationId}/access_tokens`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${appJwt}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'copilot-review-thread-resolver-worker',
    },
    body: '{}',
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      `Failed to create installation token (${response.status}): ${JSON.stringify(payload)}`,
    );
  }

  if (!payload.token) {
    throw new Error('GitHub installation token response did not include a token.');
  }

  return payload.token;
}

async function getGitHubApiToken(payload, env) {
  const directToken = env.GITHUB_TOKEN || env.GH_TOKEN;
  if (directToken) {
    return directToken;
  }

  const installationId = payload.installation?.id;
  if (!installationId) {
    throw new Error(
      'Missing installation.id in webhook payload and no GITHUB_TOKEN/GH_TOKEN fallback is configured.',
    );
  }

  return createInstallationToken(installationId, env);
}

async function createAppJwt(appId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncodeString(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64UrlEncodeString(
    JSON.stringify({
      iat: now - 60,
      exp: now + 9 * 60,
      iss: String(appId),
    }),
  );

  const signingInput = `${header}.${payload}`;
  const signingKey = await importRsaPrivateKey(privateKeyPem);
  const signatureBuffer = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    signingKey,
    textEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(signatureBuffer))}`;
}

async function importRsaPrivateKey(privateKeyPem) {
  const pemType = detectPemType(privateKeyPem);
  const der = pemToDer(privateKeyPem);
  const pkcs8 = pemType === 'pkcs1-rsa' ? wrapPkcs1InPkcs8(der) : der;

  return crypto.subtle.importKey(
    'pkcs8',
    pkcs8,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );
}

async function verifyWebhookSignature(rawBody, signatureHeader, secret) {
  if (!signatureHeader || !signatureHeader.startsWith('sha256=')) {
    return false;
  }

  const expectedHex = signatureHeader.slice('sha256='.length);
  const key = await crypto.subtle.importKey(
    'raw',
    textEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const digest = await crypto.subtle.sign('HMAC', key, textEncoder().encode(rawBody));
  const actualHex = bytesToHex(new Uint8Array(digest));
  return timingSafeEqual(actualHex, expectedHex);
}

async function githubGraphql({ token, apiUrl, query, variables }) {
  const response = await fetch(`${apiUrl}/graphql`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'copilot-review-thread-resolver-worker',
    },
    body: JSON.stringify({ query, variables }),
  });

  const payload = await response.json();
  if (!response.ok || payload.errors) {
    throw new Error(
      `GitHub GraphQL request failed (${response.status}): ${JSON.stringify(
        payload.errors || payload,
      )}`,
    );
  }

  return payload;
}

async function githubRest({ token, apiUrl, method, path, body }) {
  const response = await fetch(`${apiUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'copilot-review-thread-resolver-worker',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (response.status === 204) {
    return null;
  }

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`GitHub REST request failed (${response.status}): ${JSON.stringify(payload)}`);
  }

  return payload;
}

function detectPemType(pem) {
  if (pem.includes('BEGIN RSA PRIVATE KEY')) {
    return 'pkcs1-rsa';
  }
  if (pem.includes('BEGIN PRIVATE KEY')) {
    return 'pkcs8';
  }
  throw new Error('Unsupported private key format. Expected PKCS#8 or RSA PKCS#1 PEM.');
}

function pemToDer(pem) {
  const base64 = pem.replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '');

  return base64ToBytes(base64);
}

function wrapPkcs1InPkcs8(pkcs1Bytes) {
  const version = new Uint8Array([0x02, 0x01, 0x00]);
  const rsaEncryptionOid = new Uint8Array([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]);
  const nullParams = new Uint8Array([0x05, 0x00]);
  const algorithmIdentifier = derSequence(concatBytes(rsaEncryptionOid, nullParams));
  const privateKey = derOctetString(pkcs1Bytes);
  return derSequence(concatBytes(version, algorithmIdentifier, privateKey));
}

function derSequence(contents) {
  return concatBytes(new Uint8Array([0x30]), derLength(contents.length), contents);
}

function derOctetString(contents) {
  return concatBytes(new Uint8Array([0x04]), derLength(contents.length), contents);
}

function derLength(length) {
  if (length < 0x80) {
    return new Uint8Array([length]);
  }

  const bytes = [];
  let value = length;
  while (value > 0) {
    bytes.unshift(value & 0xff);
    value >>= 8;
  }

  return new Uint8Array([0x80 | bytes.length, ...bytes]);
}

function concatBytes(...arrays) {
  const totalLength = arrays.reduce((sum, arr) => sum + arr.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;

  for (const arr of arrays) {
    result.set(arr, offset);
    offset += arr.length;
  }

  return result;
}

function base64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64UrlEncodeString(value) {
  return toBase64Url(btoa(value));
}

function base64UrlEncodeBytes(bytes) {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return toBase64Url(btoa(binary));
}

function toBase64Url(base64) {
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function bytesToHex(bytes) {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function timingSafeEqual(a, b) {
  const maxLength = Math.max(a.length, b.length);
  let mismatch = a.length ^ b.length;

  for (let i = 0; i < maxLength; i += 1) {
    const aCode = i < a.length ? a.charCodeAt(i) : 0;
    const bCode = i < b.length ? b.charCodeAt(i) : 0;
    mismatch |= aCode ^ bCode;
  }

  return mismatch === 0;
}

function parseBoolean(value, defaultValue) {
  if (value == null || value === '') {
    return defaultValue;
  }
  return /^(1|true|yes|on)$/i.test(String(value));
}

function assertRequiredEnv(env) {
  const required = ['GITHUB_WEBHOOK_SECRET'];
  const missing = required.filter((key) => !env[key]);

  const hasDirectToken = Boolean(env.GITHUB_TOKEN || env.GH_TOKEN);
  const hasGitHubAppConfig = Boolean(env.GITHUB_APP_ID && env.GITHUB_APP_PRIVATE_KEY);

  if (!hasDirectToken && !hasGitHubAppConfig) {
    missing.push('GITHUB_TOKEN/GH_TOKEN or GITHUB_APP_ID+GITHUB_APP_PRIVATE_KEY');
  }

  if (missing.length > 0) {
    throw new Error(`Missing required Worker env vars: ${missing.join(', ')}`);
  }
}

function textEncoder() {
  return new TextEncoder();
}

function stringifyError(error) {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
    },
  });
}
