-- Migration: Create async chat transport tables
-- Description: Task lifecycle + message log + sync checkpoints for async conversation transport.
-- Version: 007
-- Date: 2026-04-07

CREATE TABLE IF NOT EXISTS chat_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  session_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  resolved_bot_id VARCHAR(255),
  resolved_skill_id VARCHAR(255),
  idempotency_key VARCHAR(255) NOT NULL,
  state VARCHAR(32) NOT NULL DEFAULT 'accepted',
  accepted_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, task_id),
  UNIQUE(user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_chat_tasks_user_session ON chat_tasks(user_id, session_id);
CREATE INDEX IF NOT EXISTS idx_chat_tasks_state ON chat_tasks(state);

CREATE TABLE IF NOT EXISTS chat_messages (
  seq_id SERIAL PRIMARY KEY,
  message_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_id VARCHAR(255),
  channel_id VARCHAR(255) NOT NULL,
  session_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  role VARCHAR(32) NOT NULL,
  content TEXT NOT NULL,
  task_state VARCHAR(32),
  checkpoint_cursor VARCHAR(255),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_user_session_seq
  ON chat_messages(user_id, session_id, seq_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_task_id ON chat_messages(task_id);

CREATE TABLE IF NOT EXISTS chat_sync_checkpoints (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id VARCHAR(255) NOT NULL,
  last_seq_id INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY(user_id, session_id)
);

CREATE TRIGGER update_chat_tasks_updated_at
  BEFORE UPDATE ON chat_tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_messages_updated_at
  BEFORE UPDATE ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_sync_checkpoints_updated_at
  BEFORE UPDATE ON chat_sync_checkpoints
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
