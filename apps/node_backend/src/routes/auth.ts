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

interface GitHubTokenResponse {
  access_token: string;
  token_type: string;
  scope: string;
}

// GitHub OAuth configuration
const GITHUB_CLIENT_ID = process.env.GITHUB_CLIENT_ID;
const GITHUB_CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET;
const GITHUB_CALLBACK_URL = process.env.GITHUB_CALLBACK_URL;

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
  const redirectUrl = `https://github.com/login/oauth/authorize?client_id=${GITHUB_CLIENT_ID}&scope=${scope}&redirect_uri=${GITHUB_CALLBACK_URL}`;

  res.redirect(redirectUrl);
});

/**
 * GET /auth/github/callback
 * GitHub OAuth callback handler
 */
router.get('/github/callback', async (req: Request, res: Response) => {
  try {
    const { code } = req.query;

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

    // Find or create user in our database
    const user = await findOrCreateUserByOAuth(
      'github',
      githubUser.id.toString(),
      access_token
    );

    // Generate JWT token
    const token = generateToken(user.id);

    // Return token and user info
    res.json({
      token,
      user: {
        id: user.id,
        created_at: user.created_at,
      },
    });
  } catch (error) {
    console.error('GitHub OAuth error:', error);
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
