import pool from '../db/index.js';

const OAUTH_STATE_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Stores a short-lived OAuth state nonce in the database.
 * The TTL matches the HttpOnly cookie expiry (10 minutes).
 * Used to support cross-domain OAuth flows (e.g., preview → production callback)
 * where the cookie is not available on the callback host.
 */
export async function storeOAuthState(nonce: string, returnTo: string): Promise<void> {
  const expiresAt = new Date(Date.now() + OAUTH_STATE_TTL_MS).toISOString();
  await pool.query(
    'INSERT INTO oauth_states (nonce, return_to, expires_at) VALUES ($1, $2, $3)',
    [nonce, returnTo, expiresAt]
  );
}

/**
 * Atomically looks up and marks as used a valid, unexpired OAuth state nonce.
 * Returns the `returnTo` URL recorded at initiation, or `null` if the nonce is
 * not found, already used, or expired.
 *
 * Using UPDATE…RETURNING ensures the check-and-consume is atomic so the same
 * nonce cannot be replayed by concurrent requests.
 */
export async function consumeOAuthState(nonce: string): Promise<string | null> {
  const now = new Date().toISOString();
  const result = await pool.query<{ return_to: string }>(
    `UPDATE oauth_states
     SET used = TRUE
     WHERE nonce = $1 AND used = FALSE AND expires_at > $2
     RETURNING return_to`,
    [nonce, now]
  );
  if (result.rows.length === 0) return null;
  return result.rows[0].return_to;
}
