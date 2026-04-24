-- Migration: Add node_id to chat_scope_settings
-- Description: Persist the selected OpenClaw node per chat scope so platform event delivery can target a single node.

ALTER TABLE chat_scope_settings
  ADD COLUMN IF NOT EXISTS node_id VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_chat_scope_settings_user_scope_node
  ON chat_scope_settings(user_id, channel_id, scope_type, thread_id, node_id);
