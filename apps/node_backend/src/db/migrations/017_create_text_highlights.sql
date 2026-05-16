-- Migration: Create text_highlights table
-- Description: Stores user-selected text spans from chat messages, so highlights
-- persist across page reloads and can be queried via the AI highlight_list tool.

CREATE TABLE text_highlights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id VARCHAR(255) NOT NULL,
  selected_text TEXT NOT NULL,
  start_offset INT,
  end_offset INT,
  color VARCHAR(32) NOT NULL DEFAULT 'yellow',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_text_highlights_user_id ON text_highlights(user_id);
CREATE INDEX idx_text_highlights_message_id ON text_highlights(user_id, message_id);

CREATE TRIGGER update_text_highlights_updated_at
  BEFORE UPDATE ON text_highlights
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
