-- Migration: Create asset_notes table
-- Description: User-scoped long Markdown notes managed via REST API and AI tool calls.

CREATE TABLE asset_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_notes_user_published_updated
  ON asset_notes(user_id, is_published, updated_at);

CREATE TRIGGER update_asset_notes_updated_at
  BEFORE UPDATE ON asset_notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
