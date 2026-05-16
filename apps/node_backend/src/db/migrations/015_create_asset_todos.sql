-- Migration: Create asset_todos table
-- Description: Persistent todo list items per user, manageable via AI tool calls or REST API.

CREATE TABLE asset_todos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_todos_user_id ON asset_todos(user_id, is_completed);

CREATE TRIGGER update_asset_todos_updated_at
  BEFORE UPDATE ON asset_todos
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
