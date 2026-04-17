-- Migration: Create chat_scope_settings table
-- Description: Persist explicit router settings for chat channels and threads.
-- Version: 009
-- Date: 2026-04-17

CREATE TABLE IF NOT EXISTS chat_scope_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scope_type VARCHAR(16) NOT NULL CHECK (scope_type IN ('channel', 'thread')),
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255) NOT NULL DEFAULT '',
  router VARCHAR(32) NOT NULL CHECK (router IN ('default', 'openclaw')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CHECK (
    (scope_type = 'channel' AND thread_id = '') OR
    (scope_type = 'thread' AND thread_id <> '')
  ),
  UNIQUE (user_id, scope_type, channel_id, thread_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_scope_settings_user_scope
  ON chat_scope_settings(user_id, channel_id, scope_type, thread_id);

CREATE TRIGGER update_chat_scope_settings_updated_at
  BEFORE UPDATE ON chat_scope_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
