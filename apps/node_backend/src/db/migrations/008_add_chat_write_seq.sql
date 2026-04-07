-- Migration: Add write_seq to chat_messages for incremental sync on updates
-- Description: Introduces a monotonic write-sequence counter so that message
--   updates (streaming content, taskState transitions) advance the cursor and
--   are returned by incremental syncMessages calls, fixing multi-client replay.
-- Version: 008
-- Date: 2026-04-07

-- Counter table that issues a new monotonic value on every insert/update.
CREATE TABLE IF NOT EXISTS chat_write_seq_counter (
  id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
  counter BIGINT NOT NULL DEFAULT 0
);

INSERT INTO chat_write_seq_counter (id, counter) VALUES (1, 0) ON CONFLICT DO NOTHING;

-- Add write_seq column (existing rows backfilled to their seq_id value).
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS write_seq BIGINT NOT NULL DEFAULT 0;

UPDATE chat_messages SET write_seq = seq_id WHERE write_seq = 0;

-- Advance the counter to the highest existing write_seq so new values are unique.
UPDATE chat_write_seq_counter
   SET counter = COALESCE((SELECT MAX(write_seq) FROM chat_messages), 0)
 WHERE id = 1;

CREATE INDEX IF NOT EXISTS idx_chat_messages_write_seq
  ON chat_messages(user_id, session_id, write_seq);
