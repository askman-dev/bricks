-- Migration: Create scheduled_action_runs table
-- Description: Tracks each execution attempt of a scheduled action.
--   The UNIQUE constraint on (scheduled_action_id, scheduled_fire_at) prevents
--   duplicate claims when multiple cron requests overlap.

CREATE TABLE scheduled_action_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scheduled_action_id UUID NOT NULL REFERENCES scheduled_actions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  scheduled_fire_at TIMESTAMP NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'queued',
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  error_text TEXT,
  chat_task_id VARCHAR(255),
  chat_message_id VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(scheduled_action_id, scheduled_fire_at)
);

CREATE INDEX idx_scheduled_action_runs_action_id ON scheduled_action_runs(scheduled_action_id);
CREATE INDEX idx_scheduled_action_runs_user_id ON scheduled_action_runs(user_id);

CREATE TRIGGER update_scheduled_action_runs_updated_at
  BEFORE UPDATE ON scheduled_action_runs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
