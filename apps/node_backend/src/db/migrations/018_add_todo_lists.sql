-- Migration: Add asset_todo_lists and nest asset_todos under a parent list
-- Description: Todo items must belong to a named todo list (topic group).
--   Users create a list first, then add items to it.
--   Deleting a list cascades to delete all its items.

CREATE TABLE asset_todo_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_todo_lists_user_id ON asset_todo_lists(user_id);

CREATE TRIGGER update_asset_todo_lists_updated_at
  BEFORE UPDATE ON asset_todo_lists
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add list_id to asset_todos.
-- Migrations 015 and 018 are always co-deployed in this PR; there will never
-- be any rows in asset_todos without a list_id, so the NOT NULL constraint
-- requires no back-fill step.
ALTER TABLE asset_todos
  ADD COLUMN list_id UUID NOT NULL REFERENCES asset_todo_lists(id) ON DELETE CASCADE;

CREATE INDEX idx_asset_todos_list_id ON asset_todos(user_id, list_id, is_completed);
