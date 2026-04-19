-- Migration: Create chat_channel_names table
-- Description: Persist per-user custom channel display names.
-- Version: 010
-- Date: 2026-04-18

CREATE TABLE IF NOT EXISTS chat_channel_names (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (user_id, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_channel_names_user_id
  ON chat_channel_names(user_id);

CREATE TRIGGER update_chat_channel_names_updated_at
  BEFORE UPDATE ON chat_channel_names
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
