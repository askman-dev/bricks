import { randomBytes } from 'node:crypto';
import express, { Request, Response } from 'express';
import axios from 'axios';
import { findOrCreateUserByOAuth } from '../services/userService.js';
import { generateToken, authenticate, AuthRequest } from '../middleware/auth.js';

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
const GITHUB_CALLBACK_URL = process.env.GITHUB_CALLBACK_URL;

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
 * the browser to the app root (`/`) so that Flutter's startup router can
 * pick it up via AuthService.isLoggedIn().
 *
 * If localStorage is unavailable (e.g. blocked in private mode) the page
 * shows a clear recovery message instead of silently failing.
 */
function buildRedirectResponse(res: Response, token: string): void {
  const escapedToken = JSON.stringify(token);
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
        window.location.replace('/');
      })();
    </script>
  </body>
</html>`);
}

async function handleGitHubCallback(req: Request, res: Response): Promise<void> {
  const { code, state } = req.query;

  // Validate CSRF state: compare the query parameter with the HttpOnly cookie.
  const cookies = parseCookies(req.headers.cookie);
  const expectedState = cookies[OAUTH_STATE_COOKIE];

  if (!expectedState || typeof state !== 'string' || state !== expectedState) {
    res.status(400).json({ error: 'Invalid or missing OAuth state parameter' });
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
  buildRedirectResponse(res, token);
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
  const state = randomBytes(32).toString('hex');

  // Store the nonce in a short-lived, HttpOnly, SameSite=Lax cookie.
  // Path is set to /api so it is sent back for all callback routes
  // (/api/auth/github/callback, /api/auth/callback, etc.).
  res.cookie(OAUTH_STATE_COOKIE, state, {
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
