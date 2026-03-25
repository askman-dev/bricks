-- Migration: Add email column to users table
-- Description: Stores the primary verified email fetched from GitHub OAuth
-- Version: 004
-- Date: 2026-03-25

ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL;
