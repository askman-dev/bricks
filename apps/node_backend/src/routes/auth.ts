import { randomBytes } from 'node:crypto';
import express, { Request, Response } from 'express';
import axios from 'axios';
import { findOrCreateUserByOAuth } from '../services/userService.js';
import { generateToken, authenticate, AuthRequest } from '../middleware/auth.js';
import { isAllowedReturnTo } from './auth_return_to.js';
import { storeOAuthState, consumeOAuthState } from '../services/oauthStateService.js';

const router = express.Router();

interface GitHubUser {
  id: number;
  login: string;
  name: string;
  email: string;
}

interface GitHubEmail {
  email: string;
  primary: boolean;
  verified: boolean;
  visibility: string | null;
}

interface GitHubTokenResponse {
  access_token: string;
  token_type: string;
  scope: string;
}

// GitHub OAuth configuration
const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const GITHUB_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET;
// GITHUB_CALLBACK_URL must include the full /api prefix that the router is mounted under.
// This router is mounted at both /api/auth and /api in app.ts, so the effective callback
// paths are /api/auth/github/callback and /api/github/callback.
// Correct examples:
//   Local:      http://localhost:3000/api/auth/github/callback
//   Production: https://your-domain.com/api/auth/github/callback
const GITHUB_CALLBACK_URL = process.env.GITHUB_CALLBACK_URL;
const OAUTH_ALLOWED_RETURN_ORIGINS = process.env.OAUTH_ALLOWED_RETURN_ORIGINS;
const E2E_MOCK_GITHUB_OAUTH = process.env.E2E_MOCK_GITHUB_OAUTH === 'true';
const E2E_MOCK_GITHUB_EMAIL = process.env.E2E_MOCK_GITHUB_EMAIL || 'e2e-user@bricks.local';
const E2E_MOCK_GITHUB_USER_ID = process.env.E2E_MOCK_GITHUB_USER_ID || 'bricks-e2e-github-user';

/** Name of the HttpOnly cookie used to store the CSRF state nonce. */
const OAUTH_STATE_COOKIE = 'oauth_state';

/**
 * Parses the `Cookie` request header into a key/value map.
 * Avoids a `cookie-parser` dependency while keeping the logic minimal and safe.
 */
function parseCookies(cookieHeader: string | undefined): Record<string, string> {
  const result: Record<string, string> = {};
  if (!cookieHeader) return result;
  for (const pair of cookieHeader.split(';')) {
    const idx = pair.indexOf('=');
    if (idx === -1) continue;
    const key = pair.slice(0, idx).trim();
    const value = pair.slice(idx + 1).trim();
    if (key) {
      try {
        result[key] = decodeURIComponent(value);
      } catch {
        result[key] = value;
      }
    }
  }
  return result;
}

/**
 * Builds the OAuth callback response for the redirect (non-popup) flow.
 *
 * The returned HTML page stores the JWT token in localStorage under the key
 * `auth_token` as a plain string, then redirects the browser to `redirectTo`
 * so that the React app can read it immediately after the redirect.
 *
 * If localStorage is unavailable (e.g. blocked in private mode) the page
 * shows a clear recovery message instead of silently failing.
 */
function buildRedirectResponse(res: Response, token: string, redirectTo: string): void {
  const escapedToken = JSON.stringify(token);
  const escapedRedirectTo = JSON.stringify(redirectTo);
  const nonce = randomBytes(16).toString('base64');
  // Tight CSP: only the nonced inline script is allowed; everything else is
  // locked down.  form-action is restricted to 'none' and frame-ancestors
  // prevents clickjacking.
  res.setHeader(
    'Content-Security-Policy',
    `default-src 'none'; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`
  );
  // Prevent any cache layer from storing the JWT token.
  res.setHeader('Cache-Control', 'no-store');
  res.type('html').send(`<!doctype html>
<html>
  <body>
    <p>Authentication successful. Redirecting…</p>
    <script nonce="${nonce}">
      (function () {
        var token = ${escapedToken};
        try {
          localStorage.setItem('auth_token', token);
        } catch (e) {
          console.error('bricks: localStorage unavailable', e);
          var msg = document.createElement('p');
          msg.textContent = 'Authentication successful! Please enable cookies/storage for this site and try again.';
          document.body.replaceChildren(msg);
          return;
        }
        window.location.replace(${escapedRedirectTo});
      })();
    </script>
  </body>
</html>`);
}

/**
 * Returns a browser redirect target for post-login navigation.
 *
 * For same-origin callback flows, the token is delivered via callback-origin
 * localStorage only.
 *
 * For cross-origin callback flows, append the token to URL fragment
 * (`#auth_token=...`) so the destination origin can persist it locally.
 * Fragments are not sent to the server and are consumed client-side.
 */
export function buildPostLoginRedirectTarget(
  redirectTo: string,
  token: string,
  callbackOrigin?: string,
): string {
  if (!callbackOrigin) return redirectTo;

  let target: URL;
  let callback: URL;
  try {
    target = new URL(redirectTo);
    callback = new URL(callbackOrigin);
  } catch {
    return redirectTo;
  }

  if (target.origin === callback.origin) {
    return redirectTo;
  }

  const fragment = target.hash.startsWith('#') ? target.hash.slice(1) : target.hash;

  if (fragment.startsWith('/')) {
    // Hash-based route (e.g., Flutter Web HashUrlStrategy: #/chat).
    // Append auth_token to the query portion of the route, not to the route path
    // itself, so the Flutter app can parse it without corrupting the navigation route.
    const queryIndex = fragment.indexOf('?');
    const route = queryIndex >= 0 ? fragment.slice(0, queryIndex) : fragment;
    const query = queryIndex >= 0 ? fragment.slice(queryIndex + 1) : '';
    const fragmentParams = new URLSearchParams(query);
    fragmentParams.set('auth_token', token);
    target.hash = `${route}?${fragmentParams.toString()}`;
    return target.toString();
  }

  const fragmentParams = new URLSearchParams(fragment);
  fragmentParams.set('auth_token', token);
  target.hash = fragmentParams.toString();
  return target.toString();
}

function getRequestOrigin(req: Request): string | undefined {
  // Prefer the proxy-forwarded host so that same-origin detection is correct
  // when running behind a reverse proxy (e.g., Vercel, nginx).
  const forwardedHost = req.get('x-forwarded-host');
  const host = (forwardedHost?.split(',')[0]?.trim()) || req.get('host');
  if (!host) return undefined;
  const forwardedProto = req.get('x-forwarded-proto');
  const proto = forwardedProto?.split(',')[0]?.trim() || req.protocol || 'https';
  return `${proto}://${host}`;
}

export interface OAuthStatePayload {
  nonce: string;
  returnTo: string;
}

export function decodeOAuthState(state: string): OAuthStatePayload | null {
  try {
    const parsed = JSON.parse(
      Buffer.from(state, 'base64url').toString('utf8')
    ) as Partial<OAuthStatePayload>;
    if (
      typeof parsed.nonce !== 'string'
      || typeof parsed.returnTo !== 'string'
    ) {
      return null;
    }
    return { nonce: parsed.nonce, returnTo: parsed.returnTo };
  } catch {
    return null;
  }
}

/** Injected lookup function type; allows unit tests to substitute a mock. */
export type OAuthStateLookup = (nonce: string) => Promise<string | null>;

/**
 * Validates the OAuth callback state parameter.
 *
 * Two acceptance paths, in priority order:
 *   1. Cookie match  – a same-host flow where the HttpOnly `oauth_state` cookie
 *      is present and its nonce matches the one in the state payload.
 *   2. Server-side store – a cross-domain flow (e.g., preview → production) where
 *      the cookie is absent; the nonce is consumed from the shared database record
 *      created at flow initiation.  The `returnTo` URL is taken from the database
 *      record (not the state parameter) to prevent tampering.
 *
 * The legacy plain-hex nonce format is supported for in-flight sessions that were
 * started before the base64url JSON format was deployed.
 *
 * @param stateParam   Raw `state` query parameter from the callback URL.
 * @param cookieNonce  Value of the `oauth_state` HttpOnly cookie, or undefined.
 * @param lookupStoredState  Async function that consumes a nonce from the server-side
 *                           store and returns the associated `returnTo` URL, or null.
 */
export async function validateOAuthCallbackState(
  stateParam: string | undefined,
  cookieNonce: string | undefined,
  lookupStoredState: OAuthStateLookup,
): Promise<{ valid: true; returnTo: string } | { valid: false }> {
  let statePayload: OAuthStatePayload | null = null;

  if (typeof stateParam === 'string') {
    statePayload = decodeOAuthState(stateParam);
    // Legacy path: plain 64-hex-char nonce sent directly as the state value.
    if (!statePayload && /^[0-9a-f]{64}$/i.test(stateParam) && stateParam === cookieNonce) {
      statePayload = { nonce: stateParam, returnTo: getDefaultReturnTo() };
    }
  }

  const hasStateCookie = typeof cookieNonce === 'string' && cookieNonce.length > 0;

  if (hasStateCookie) {
    // Cookie is present: nonce MUST match.  Do not fall through to the
    // server-side store – a mismatch should be a hard rejection.
    if (statePayload && statePayload.nonce === cookieNonce) {
      return { valid: true, returnTo: statePayload.returnTo };
    }
    return { valid: false };
  }

  // No cookie: attempt to consume the nonce from the server-side state store.
  // This covers cross-domain flows where the cookie was set on the initiating
  // host (e.g., a Vercel preview URL) but the callback lands on a different host.
  if (!statePayload) {
    return { valid: false };
  }

  const storedReturnTo = await lookupStoredState(statePayload.nonce);
  if (storedReturnTo === null) {
    return { valid: false };
  }

  // Use the returnTo from the DB record, not from the state parameter, to
  // prevent open-redirect attacks via a crafted state payload.
  return { valid: true, returnTo: storedReturnTo };
}

function getDefaultReturnTo(): string {
  if (GITHUB_CALLBACK_URL) {
    try {
      const callbackUrl = new URL(GITHUB_CALLBACK_URL);
      return `${callbackUrl.origin}/`;
    } catch {
      // Fall through to localhost below.
    }
  }
  return 'http://localhost:3000/';
}

export function canUseE2EMockGithubOAuth(): boolean {
  return process.env.E2E_MOCK_GITHUB_OAUTH === 'true' && process.env.NODE_ENV !== 'production';
}

async function handleGitHubCallback(req: Request, res: Response): Promise<void> {
  const { code, state } = req.query;

  // Validate CSRF state via cookie nonce match (same-host) or server-side
  // nonce store (cross-domain).  See validateOAuthCallbackState for details.
  const cookies = parseCookies(req.headers.cookie);
  const cookieNonce = cookies[OAUTH_STATE_COOKIE];

  const validationResult = await validateOAuthCallbackState(
    typeof state === 'string' ? state : undefined,
    cookieNonce,
    consumeOAuthState,
  );

  if (!validationResult.valid) {
    res.status(400).json({ error: 'Invalid or missing OAuth state parameter' });
    return;
  }

  const returnTo = validationResult.returnTo;

  // Re-validate returnTo for defense in depth. The default (callback origin) is
  // implicitly trusted; user-supplied values must still pass isAllowedReturnTo.
  const defaultReturnTo = getDefaultReturnTo();
  if (
    returnTo !== defaultReturnTo
    && !isAllowedReturnTo(returnTo, {
    callbackUrl: GITHUB_CALLBACK_URL,
    allowedReturnOrigins: OAUTH_ALLOWED_RETURN_ORIGINS,
  })
  ) {
    res.status(400).json({ error: 'Invalid OAuth return_to parameter' });
    return;
  }

  // Clear the one-time state cookie regardless of what happens next.
  res.clearCookie(OAUTH_STATE_COOKIE, { path: '/api' });

  if (!code || typeof code !== 'string') {
    res.status(400).json({ error: 'Authorization code required' });
    return;
  }

  if (!GITHUB_CLIENT_ID || !GITHUB_CLIENT_SECRET) {
    res.status(500).json({ error: 'GitHub OAuth not configured' });
    return;
  }

  // Exchange code for access token
  const tokenResponse = await axios.post<GitHubTokenResponse>(
    'https://github.com/login/oauth/access_token',
    {
      client_id: GITHUB_CLIENT_ID,
      client_secret: GITHUB_CLIENT_SECRET,
      code,
      redirect_uri: GITHUB_CALLBACK_URL,
    },
    {
      headers: { Accept: 'application/json' },
    }
  );

  const { access_token } = tokenResponse.data;

  if (!access_token) {
    res.status(400).json({ error: 'Failed to obtain access token' });
    return;
  }

  // Get GitHub user info
  const userResponse = await axios.get<GitHubUser>(
    'https://api.github.com/user',
    {
      headers: {
        Authorization: `Bearer ${access_token}`,
        Accept: 'application/json',
      },
    }
  );

  const githubUser = userResponse.data;

  // Get GitHub user emails to find the primary verified email
  const emailsResponse = await axios.get<GitHubEmail[]>(
    'https://api.github.com/user/emails',
    {
      headers: {
        Authorization: `Bearer ${access_token}`,
        Accept: 'application/json',
      },
    }
  );

  const primaryEmail = emailsResponse.data.find(e => e.primary && e.verified)?.email
    ?? emailsResponse.data.find(e => e.verified)?.email
    ?? null;

  // Find or create user in our database
  const user = await findOrCreateUserByOAuth(
    'github',
    githubUser.id.toString(),
    access_token,
    undefined,
    undefined,
    primaryEmail ?? undefined
  );

  // Generate JWT token and deliver it to the Flutter app via the redirect flow.
  const token = generateToken(user.id);
  const callbackOrigin = getRequestOrigin(req);
  const redirectTarget = buildPostLoginRedirectTarget(returnTo, token, callbackOrigin);
  buildRedirectResponse(res, token, redirectTarget);
}

/**
 * GET /auth/github
 * Redirects the current browser tab to the GitHub OAuth consent screen.
 * A random CSRF state nonce is generated, stored in a short-lived HttpOnly
 * cookie, and persisted in the server-side state store so that the callback
 * can verify it whether or not the cookie is forwarded (e.g., cross-domain
 * preview → production flows).
 */
router.get('/github', async (req: Request, res: Response) => {
  if (canUseE2EMockGithubOAuth()) {
    try {
      const isDefaultReturnTo = typeof req.query.return_to !== 'string';
      const returnTo = isDefaultReturnTo ? getDefaultReturnTo() : req.query.return_to as string;

      if (!isDefaultReturnTo && !isAllowedReturnTo(returnTo, {
        callbackUrl: GITHUB_CALLBACK_URL,
        allowedReturnOrigins: OAUTH_ALLOWED_RETURN_ORIGINS,
      })) {
        res.status(400).json({ error: 'Invalid return_to URL' });
        return;
      }

      const user = await findOrCreateUserByOAuth(
        'github',
        E2E_MOCK_GITHUB_USER_ID,
        'e2e-mock-access-token',
        undefined,
        undefined,
        E2E_MOCK_GITHUB_EMAIL,
      );

      const token = generateToken(user.id);
      const callbackOrigin = getRequestOrigin(req);
      const redirectTarget = buildPostLoginRedirectTarget(returnTo, token, callbackOrigin);
      buildRedirectResponse(res, token, redirectTarget);
      return;
    } catch (error) {
      console.error('GitHub OAuth E2E mock login error:', error);
      res.status(500).json({ error: 'Authentication setup failed' });
      return;
    }
  }

  if (!GITHUB_CLIENT_ID) {
    res.status(500).json({ error: 'GitHub OAuth not configured' });
    return;
  }

  if (!GITHUB_CALLBACK_URL) {
    res.status(500).json({ error: 'GitHub OAuth callback URL not configured' });
    return;
  }

  try {
    // Generate a cryptographically random state nonce for CSRF protection.
    const nonce = randomBytes(32).toString('hex');
    const isDefaultReturnTo = typeof req.query.return_to !== 'string';
    const returnTo = isDefaultReturnTo ? getDefaultReturnTo() : req.query.return_to as string;
    // Only validate user-supplied return_to values; the default is derived
    // from our own callback origin and is therefore implicitly trusted.
    if (!isDefaultReturnTo && !isAllowedReturnTo(returnTo, {
      callbackUrl: GITHUB_CALLBACK_URL,
      allowedReturnOrigins: OAUTH_ALLOWED_RETURN_ORIGINS,
    })) {
      res.status(400).json({ error: 'Invalid return_to URL' });
      return;
    }

    const statePayload: OAuthStatePayload = { nonce, returnTo };
    const state = Buffer.from(
      JSON.stringify(statePayload),
      'utf8'
    ).toString('base64url');

    // Store the nonce server-side so cross-domain callbacks can validate it
    // even when the HttpOnly cookie is not forwarded by the browser.
    await storeOAuthState(nonce, returnTo);

    // Store the nonce in a short-lived, HttpOnly, SameSite=Lax cookie.
    // Path is set to /api so it is sent back for all callback routes
    // (/api/auth/github/callback, /api/auth/callback, etc.).
    res.cookie(OAUTH_STATE_COOKIE, nonce, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/api',
      maxAge: 10 * 60 * 1000, // 10 minutes
    });

    const scope = 'read:user user:email';
    const redirectUrl = `https://github.com/login/oauth/authorize?client_id=${GITHUB_CLIENT_ID}&scope=${scope}&redirect_uri=${encodeURIComponent(GITHUB_CALLBACK_URL)}&state=${encodeURIComponent(state)}`;

    res.redirect(redirectUrl);
  } catch (error) {
    console.error('GitHub OAuth init error:', error);
    res.status(500).json({ error: 'Authentication setup failed' });
  }
});

/**
 * GET /auth/github/callback
 * GitHub OAuth callback handler
 */
router.get('/github/callback', async (req: Request, res: Response) => {
  try {
    await handleGitHubCallback(req, res);
  } catch (error) {
    console.error('GitHub OAuth error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

/**
 * GET /callback
 * Alternate callback route used by app-level OAuth callback URLs.
 */
router.get('/callback', async (req: Request, res: Response) => {
  try {
    await handleGitHubCallback(req, res);
  } catch (error) {
    console.error('GitHub OAuth callback error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

/**
 * GET /auth/me
 * Get current user info (requires authentication)
 */
router.get('/me', authenticate, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { getUserById, getOAuthConnections } = await import('../services/userService.js');
    const user = await getUserById(userId);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const oauthConnections = await getOAuthConnections(userId);

    res.json({
      user: {
        id: user.id,
        email: user.email ?? null,
        created_at: user.created_at,
        updated_at: user.updated_at,
      },
      oauth_connections: oauthConnections.map(conn => ({
        provider: conn.provider,
        provider_user_id: conn.provider_user_id,
        created_at: conn.created_at,
      })),
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * DELETE /auth/me
 * Delete current user account (requires authentication)
 */
router.delete('/me', authenticate, async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { deleteUser } = await import('../services/userService.js');
    const deleted = await deleteUser(userId);

    if (!deleted) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
