-- Migration: Create chat_thread_forks table
-- Description: Tracks thread fork relationships so that forked threads can
--   inherit context from a parent thread up to a specific message.
--   When assembling LLM context, messages from the parent session up to
--   (and including) the fork point are prepended before the forked session's
--   own messages.
-- Version: 023
-- Date: 2026-06-03

CREATE TABLE IF NOT EXISTS chat_thread_forks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  forked_session_id VARCHAR(255) NOT NULL,
  parent_session_id VARCHAR(255) NOT NULL,
  fork_message_id VARCHAR(255) NOT NULL,
  fork_write_seq BIGINT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, forked_session_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_thread_forks_forked_session
  ON chat_thread_forks(user_id, forked_session_id);
