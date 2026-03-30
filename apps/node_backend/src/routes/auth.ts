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

interface OAuthStatePayload {
  mode?: 'popup';
  return_origin?: string;
}

// GitHub OAuth configuration
const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const GITHUB_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET;
const GITHUB_CALLBACK_URL = process.env.GITHUB_CALLBACK_URL;
const OAUTH_ALLOWED_RETURN_ORIGINS = process.env.OAUTH_ALLOWED_RETURN_ORIGINS;

function parseStatePayload(stateValue: string | undefined): OAuthStatePayload {
  if (!stateValue) {
    return {};
  }

  try {
    const decoded = Buffer.from(stateValue, 'base64url').toString('utf8');
    const payload = JSON.parse(decoded) as OAuthStatePayload;
    return payload ?? {};
  } catch {
    return {};
  }
}

function resolveAllowedReturnOrigins(req: Request): Set<string> {
  const allowed = new Set<string>();
  const requestOrigin = `${req.protocol}://${req.get('host')}`;
  allowed.add(requestOrigin);

  if (GITHUB_CALLBACK_URL) {
    try {
      allowed.add(new URL(GITHUB_CALLBACK_URL).origin);
    } catch {
      // Ignore malformed callback URL and fall back to request origin.
    }
  }

  if (OAUTH_ALLOWED_RETURN_ORIGINS) {
    OAUTH_ALLOWED_RETURN_ORIGINS
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean)
      .forEach((origin) => allowed.add(origin));
  }

  return allowed;
}

function isAllowedReturnOrigin(returnOrigin: string, req: Request): boolean {
  try {
    const parsed = new URL(returnOrigin);
    if (parsed.protocol !== 'https:') {
      return false;
    }

    if (resolveAllowedReturnOrigins(req).has(parsed.origin)) {
      return true;
    }

    return parsed.hostname.endsWith('.vercel.app');
  } catch {
    return false;
  }
}

function buildPopupResponse(res: Response, token: string, returnOrigin: string): void {
  const escapedToken = JSON.stringify(token);
  const escapedOrigin = JSON.stringify(returnOrigin);
  const nonce = randomBytes(16).toString('base64');
  // Override Helmet's default CSP for this page: only the nonced inline script
  // needs to run; everything else can stay locked down.
  res.setHeader(
    'Content-Security-Policy',
    `default-src 'none'; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`
  );
  res.type('html').send(`<!doctype html>
<html>
  <body>
    <p>Authentication successful. This window will close automatically.</p>
    <script nonce="${nonce}">
      (function () {
        var token = ${escapedToken};
        var returnOrigin = ${escapedOrigin};
        if (window.opener) {
          window.opener.postMessage({ type: 'bricks:github-auth', token: token }, returnOrigin);
          window.close();
          return;
        }
        window.location.replace(returnOrigin + '/?auth_token=' + encodeURIComponent(token));
      })();
    </script>
  </body>
</html>`);
}

async function handleGitHubCallback(req: Request, res: Response): Promise<void> {
  const { code, state } = req.query;
  const parsedState = parseStatePayload(typeof state === 'string' ? state : undefined);

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

  // Generate JWT token
  const token = generateToken(user.id);

  if (parsedState.mode === 'popup') {
    const fallbackOrigin = `${req.protocol}://${req.get('host')}`;
    const returnOrigin = parsedState.return_origin && isAllowedReturnOrigin(parsedState.return_origin, req)
      ? parsedState.return_origin
      : fallbackOrigin;

    buildPopupResponse(res, token, returnOrigin);
    return;
  }

  // Return token and user info
  res.json({
    token,
    user: {
      id: user.id,
      email: user.email ?? null,
      created_at: user.created_at,
    },
  });
}

/**
 * GET /auth/github
 * Redirects user to GitHub OAuth consent screen
 */
router.get('/github', (req: Request, res: Response) => {
  if (!GITHUB_CLIENT_ID) {
    res.status(500).json({ error: 'GitHub OAuth not configured' });
    return;
  }

  const scope = 'read:user user:email';
  const requestedOrigin = typeof req.query.origin === 'string' ? req.query.origin : undefined;
  const returnOrigin = requestedOrigin && isAllowedReturnOrigin(requestedOrigin, req)
    ? requestedOrigin
    : `${req.protocol}://${req.get('host')}`;
  const statePayload: OAuthStatePayload | undefined = req.query.mode === 'popup'
    ? { mode: 'popup', return_origin: returnOrigin }
    : undefined;
  const state = statePayload
    ? Buffer.from(JSON.stringify(statePayload), 'utf8').toString('base64url')
    : undefined;
  const stateQuery = state ? `&state=${encodeURIComponent(state)}` : '';
  const redirectUrl = `https://github.com/login/oauth/authorize?client_id=${GITHUB_CLIENT_ID}&scope=${scope}&redirect_uri=${GITHUB_CALLBACK_URL}${stateQuery}`;

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
