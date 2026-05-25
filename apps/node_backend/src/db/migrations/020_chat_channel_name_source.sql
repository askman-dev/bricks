-- Migration: Track chat channel name source
-- Description: Record whether a display name was manual or automatically derived.
-- Version: 020
-- Date: 2026-05-21

ALTER TABLE chat_channel_names
  ADD COLUMN IF NOT EXISTS source VARCHAR(64) NOT NULL DEFAULT 'manual';

ALTER TABLE chat_channel_names
  ADD COLUMN IF NOT EXISTS generated_name_attempted_at TIMESTAMP NULL;
