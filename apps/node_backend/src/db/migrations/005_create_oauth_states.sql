-- Migration: Create oauth_states table
-- Description: Short-lived server-side nonce store for OAuth CSRF state validation.
--   Allows cross-domain preview→production OAuth flows to succeed while preserving
--   CSRF protections (nonce is one-time use, server-side, expires after 10 minutes).
-- Version: 005
-- Date: 2026-04-02

CREATE TABLE IF NOT EXISTS oauth_states (
  nonce VARCHAR(64) PRIMARY KEY,
  return_to TEXT NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_oauth_states_expires_at ON oauth_states(expires_at);
