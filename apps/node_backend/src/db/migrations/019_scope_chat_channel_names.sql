-- Migration: Scope chat channel names to optional threads
-- Description: Allow the existing display-name table to store subsection labels.
-- Version: 019
-- Date: 2026-05-19

ALTER TABLE chat_channel_names
  ADD COLUMN IF NOT EXISTS thread_id VARCHAR(255) NOT NULL DEFAULT '';

ALTER TABLE chat_channel_names
  DROP CONSTRAINT IF EXISTS chat_channel_names_user_id_channel_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_channel_names_scope_unique
  ON chat_channel_names(user_id, channel_id, thread_id);

CREATE INDEX IF NOT EXISTS idx_chat_channel_names_user_scope
  ON chat_channel_names(user_id, channel_id, thread_id);
