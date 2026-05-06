-- Migration: Rename chat router values to dispatch strategies
-- Description: Normalize chat_scope_settings.router from platform-specific values to dispatch strategy values.

CREATE TABLE chat_scope_settings_router_migration (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scope_type VARCHAR(16) NOT NULL CHECK (scope_type IN ('channel', 'thread')),
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255) NOT NULL DEFAULT '',
  router VARCHAR(32) NOT NULL CHECK (router IN ('local', 'plugin')),
  node_id VARCHAR(64),
  instructions TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CHECK (
    (scope_type = 'channel' AND thread_id = '') OR
    (scope_type = 'thread' AND thread_id <> '')
  ),
  UNIQUE (user_id, scope_type, channel_id, thread_id)
);

INSERT INTO chat_scope_settings_router_migration (
  id,
  user_id,
  scope_type,
  channel_id,
  thread_id,
  router,
  node_id,
  instructions,
  created_at,
  updated_at
)
SELECT
  id,
  user_id,
  scope_type,
  channel_id,
  thread_id,
  CASE
    WHEN router = 'openclaw' THEN 'plugin'
    WHEN router = 'plugin' THEN 'plugin'
    ELSE 'local'
  END,
  node_id,
  instructions,
  created_at,
  updated_at
FROM chat_scope_settings;

DROP TABLE chat_scope_settings;

ALTER TABLE chat_scope_settings_router_migration
  RENAME TO chat_scope_settings;

CREATE INDEX IF NOT EXISTS idx_chat_scope_settings_user_scope
  ON chat_scope_settings(user_id, channel_id, scope_type, thread_id);

CREATE INDEX IF NOT EXISTS idx_chat_scope_settings_user_scope_node
  ON chat_scope_settings(user_id, channel_id, scope_type, thread_id, node_id);

CREATE TRIGGER update_chat_scope_settings_updated_at
  BEFORE UPDATE ON chat_scope_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
