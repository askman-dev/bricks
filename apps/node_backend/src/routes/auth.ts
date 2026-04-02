import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import express, { Request, Response } from 'express';
import axios from 'axios';
import { findOrCreateUserByOAuth } from '../services/userService.js';
import { generateToken, authenticate, AuthRequest } from '../middleware/auth.js';
import { isAllowedReturnTo } from './auth_return_to.js';

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
 * The returned HTML page stores the JWT token in localStorage using the key
 * and encoding format expected by Flutter Web's shared_preferences plugin
 * (key: `flutter.auth_token`, value: JSON.stringify(token)), then redirects
 * the browser to `redirectTo` so that Flutter's startup router can
 * pick it up via AuthService.isLoggedIn().
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
        // Flutter Web's shared_preferences plugin stores String values as
        // JSON.stringify(value) under the key prefix 'flutter.'.
        // Writing directly here lets the Flutter startup router read the
        // token immediately after the redirect without any extra round-trip.
        try {
          localStorage.setItem('flutter.auth_token', JSON.stringify(token));
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

interface OAuthStatePayload {
  nonce: string;
  returnTo: string;
  sig?: string;
}

function decodeOAuthState(state: string): OAuthStatePayload | null {
  try {
    const parsed = JSON.parse(
      Buffer.from(state, 'base64url').toString('utf8')
    ) as Partial<OAuthStatePayload>;
    if (
      typeof parsed.nonce !== 'string'
      || typeof parsed.returnTo !== 'string'
      || (parsed.sig !== undefined && typeof parsed.sig !== 'string')
    ) {
      return null;
    }
    return { nonce: parsed.nonce, returnTo: parsed.returnTo, sig: parsed.sig };
  } catch {
    return null;
  }
}

function getOAuthStateSigningSecret(): string | null {
  return process.env.JWT_SECRET || GITHUB_CLIENT_SECRET || null;
}

function signOAuthState(nonce: string, returnTo: string, secret: string): string {
  return createHmac('sha256', secret)
    .update(`${nonce}:${returnTo}`)
    .digest('base64url');
}

function isValidOAuthStateSignature(statePayload: OAuthStatePayload, secret: string): boolean {
  if (!statePayload.sig) {
    return false;
  }

  const expectedSig = signOAuthState(statePayload.nonce, statePayload.returnTo, secret);
  const providedSig = statePayload.sig;

  try {
    return timingSafeEqual(
      Buffer.from(providedSig, 'utf8'),
      Buffer.from(expectedSig, 'utf8')
    );
  } catch {
    return false;
  }
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

async function handleGitHubCallback(req: Request, res: Response): Promise<void> {
  const { code, state } = req.query;

  // Validate CSRF state: compare nonce in query state payload with HttpOnly cookie.
  const cookies = parseCookies(req.headers.cookie);
  const expectedState = cookies[OAUTH_STATE_COOKIE];
  const oauthStateSigningSecret = getOAuthStateSigningSecret();

  // Support both the new base64url JSON format and the legacy plain hex nonce
  // format (used by flows initiated before this change was deployed) to avoid
  // breaking in-flight OAuth sessions during rollout.
  let statePayload: OAuthStatePayload | null = null;
  if (typeof state === 'string') {
    statePayload = decodeOAuthState(state);
    if (!statePayload && /^[0-9a-f]{64}$/i.test(state) && state === expectedState) {
      // Legacy flow: state is a plain hex nonce stored directly in the cookie.
      // Redirect to the default safe destination instead of returning 400.
      statePayload = { nonce: state, returnTo: getDefaultReturnTo() };
    }
  }

  const hasStateCookie = typeof expectedState === 'string' && expectedState.length > 0;
  const cookieStateValid = hasStateCookie
    && !!statePayload
    && statePayload.nonce === expectedState;
  const signedStateValid = !hasStateCookie
    && !!statePayload
    && !!oauthStateSigningSecret
    && isValidOAuthStateSignature(statePayload, oauthStateSigningSecret);

  if (!cookieStateValid && !signedStateValid) {
    res.status(400).json({ error: 'Invalid or missing OAuth state parameter' });
    return;
  }
  const validatedStatePayload = statePayload!;

  // Re-validate returnTo for defense in depth. The default (callback origin) is
  // implicitly trusted; user-supplied values must still pass isAllowedReturnTo.
  const defaultReturnTo = getDefaultReturnTo();
  if (
    validatedStatePayload.returnTo !== defaultReturnTo
    && !isAllowedReturnTo(validatedStatePayload.returnTo, {
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
  buildRedirectResponse(res, token, validatedStatePayload.returnTo);
}

/**
 * GET /auth/github
 * Redirects the current browser tab to the GitHub OAuth consent screen.
 * A random CSRF state nonce is generated, stored in a short-lived HttpOnly
 * cookie, and included in the GitHub authorize URL so the callback can
 * verify it and reject forged requests.
 */
router.get('/github', (req: Request, res: Response) => {
  if (!GITHUB_CLIENT_ID) {
    res.status(500).json({ error: 'GitHub OAuth not configured' });
    return;
  }

  if (!GITHUB_CALLBACK_URL) {
    res.status(500).json({ error: 'GitHub OAuth callback URL not configured' });
    return;
  }

  // Generate a cryptographically random state nonce for CSRF protection.
  const nonce = randomBytes(32).toString('hex');
  const oauthStateSigningSecret = getOAuthStateSigningSecret();
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
  const signedState: OAuthStatePayload = {
    nonce,
    returnTo,
  };
  if (oauthStateSigningSecret) {
    signedState.sig = signOAuthState(nonce, returnTo, oauthStateSigningSecret);
  }

  const state = Buffer.from(
    JSON.stringify(signedState satisfies OAuthStatePayload),
    'utf8'
  ).toString('base64url');

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
