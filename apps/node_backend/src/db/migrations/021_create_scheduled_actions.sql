-- Migration: Create scheduled_actions table
-- Description: Stores user-defined scheduled actions for automated agent execution.
--   Users create and manage scheduled actions through conversation;
--   a cron tick queries due actions and starts normal Agent execution.

CREATE TABLE scheduled_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  title TEXT NOT NULL,
  prompt TEXT NOT NULL,
  schedule_expr TEXT NOT NULL,
  interval_seconds INT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  next_run_at TIMESTAMP NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_scheduled_actions_user_id ON scheduled_actions(user_id);
CREATE INDEX idx_scheduled_actions_due ON scheduled_actions(next_run_at, status);

CREATE TRIGGER update_scheduled_actions_updated_at
  BEFORE UPDATE ON scheduled_actions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
