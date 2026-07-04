-- Migration: Add channel output tone and grammar fixer settings
-- Description: Store channel-scoped output style and input grammar helper flags.
-- Version: 025
-- Date: 2026-06-17

ALTER TABLE chat_scope_settings
  ADD COLUMN IF NOT EXISTS output_tone_type VARCHAR(16);

ALTER TABLE chat_scope_settings
  ADD COLUMN IF NOT EXISTS output_tone_preset VARCHAR(32);

ALTER TABLE chat_scope_settings
  ADD COLUMN IF NOT EXISTS output_tone_custom TEXT;

ALTER TABLE chat_scope_settings
  ADD COLUMN IF NOT EXISTS input_grammar_fixer_enabled BOOLEAN NOT NULL DEFAULT FALSE;
