-- Migration: Create chat_channels registry
-- Description: Replace chat_channel_names with lifecycle-aware channel/thread scope rows.
-- Version: 025
-- Date: 2026-06-23

CREATE TABLE IF NOT EXISTS chat_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255) NOT NULL DEFAULT '',
  scope_type VARCHAR(32) NOT NULL DEFAULT 'channel',
  display_name VARCHAR(255) NOT NULL,
  source VARCHAR(64) NOT NULL DEFAULT 'manual',
  generated_name_attempted_at TIMESTAMP NULL,
  archived_at TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (user_id, channel_id, thread_id)
);

INSERT INTO chat_channels (
  user_id,
  channel_id,
  thread_id,
  scope_type,
  display_name,
  source,
  generated_name_attempted_at,
  created_at,
  updated_at
)
SELECT
  user_id,
  channel_id,
  COALESCE(thread_id, ''),
  CASE WHEN COALESCE(thread_id, '') = '' THEN 'channel' ELSE 'thread' END,
  display_name,
  source,
  generated_name_attempted_at,
  created_at,
  updated_at
FROM chat_channel_names
WHERE TRUE
ON CONFLICT (user_id, channel_id, thread_id)
DO UPDATE SET
  scope_type = EXCLUDED.scope_type,
  display_name = EXCLUDED.display_name,
  source = EXCLUDED.source,
  generated_name_attempted_at = EXCLUDED.generated_name_attempted_at,
  updated_at = EXCLUDED.updated_at;

CREATE INDEX IF NOT EXISTS idx_chat_channels_user_active
  ON chat_channels(user_id, archived_at);

CREATE INDEX IF NOT EXISTS idx_chat_channels_scope
  ON chat_channels(user_id, channel_id, thread_id);

CREATE TRIGGER update_chat_channels_updated_at
  BEFORE UPDATE ON chat_channels
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Keep chat_channel_names as a deprecated rollback backup.
-- Runtime code no longer reads or writes this table after this migration.
-- Drop it only in a separate cleanup migration after production validation.
