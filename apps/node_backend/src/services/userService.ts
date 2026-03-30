import pool from '../db/index.js';

export interface User {
  id: string;
  email?: string;
  created_at: Date;
  updated_at: Date;
}

export interface OAuthConnection {
  id: string;
  user_id: string;
  provider: string;
  provider_user_id: string;
  access_token?: string;
  refresh_token?: string;
  expires_at?: Date;
  created_at: Date;
}

// Find or create user by OAuth provider
export async function findOrCreateUserByOAuth(
  provider: string,
  providerUserId: string,
  accessToken?: string,
  refreshToken?: string,
  expiresAt?: Date,
  email?: string
): Promise<User> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check if OAuth connection exists
    const oauthResult = await client.query(
      'SELECT user_id FROM oauth_connections WHERE provider = $1 AND provider_user_id = $2',
      [provider, providerUserId]
    );

    let userId: string;

    if (oauthResult.rows.length > 0) {
      // User exists, update tokens if provided
      userId = oauthResult.rows[0].user_id;

      if (accessToken) {
        await client.query(
          `UPDATE oauth_connections
           SET access_token = $1, refresh_token = $2, expires_at = $3
           WHERE provider = $4 AND provider_user_id = $5`,
          [accessToken ?? null, refreshToken ?? null, expiresAt ?? null, provider, providerUserId]
        );
      }

      if (email) {
        await client.query(
          'UPDATE users SET email = $1 WHERE id = $2 AND (email IS NULL OR email != $1)',
          [email, userId]
        );
      }
    } else {
      // Create new user
      const userResult = await client.query(
        'INSERT INTO users (email) VALUES ($1) RETURNING *',
        [email ?? null]
      );
      userId = userResult.rows[0].id;

      // Create OAuth connection
      await client.query(
        `INSERT INTO oauth_connections
         (user_id, provider, provider_user_id, access_token, refresh_token, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, provider, providerUserId, accessToken ?? null, refreshToken ?? null, expiresAt ?? null]
      );
    }

    // Get user
    const userResult = await client.query(
      'SELECT * FROM users WHERE id = $1',
      [userId]
    );

    await client.query('COMMIT');

    return userResult.rows[0] as User;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Get user by ID
export async function getUserById(userId: string): Promise<User | null> {
  const result = await pool.query(
    'SELECT * FROM users WHERE id = $1',
    [userId]
  );

  return result.rows[0] || null;
}

// Get OAuth connections for user
export async function getOAuthConnections(userId: string): Promise<OAuthConnection[]> {
  const result = await pool.query(
    'SELECT id, user_id, provider, provider_user_id, expires_at, created_at FROM oauth_connections WHERE user_id = $1',
    [userId]
  );

  return result.rows;
}

// Delete user (cascades to OAuth connections and API configs)
export async function deleteUser(userId: string): Promise<boolean> {
  const result = await pool.query(
    'DELETE FROM users WHERE id = $1',
    [userId]
  );

  return result.rowCount !== null && result.rowCount > 0;
}
