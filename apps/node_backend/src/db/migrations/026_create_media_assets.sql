-- Migration: Create media assets
-- Description: Channel-scoped uploaded and generated media files.
-- Version: 026
-- Date: 2026-06-29

CREATE TABLE IF NOT EXISTS media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  kind VARCHAR(32) NOT NULL CHECK (kind IN ('image', 'video', 'file')),
  origin VARCHAR(64) NOT NULL CHECK (origin IN ('user_upload', 'generated_image', 'generated_video')),
  status VARCHAR(32) NOT NULL DEFAULT 'ready',
  mime_type VARCHAR(255) NOT NULL,
  filename TEXT NOT NULL,
  channel_relative_path TEXT NOT NULL,
  thumbnail_channel_relative_path TEXT,
  size_bytes INTEGER NOT NULL,
  width INTEGER,
  height INTEGER,
  duration_ms INTEGER,
  source_message_id VARCHAR(255),
  provider VARCHAR(64),
  provider_operation_name TEXT,
  prompt TEXT,
  error_text TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_assets_user_channel_created
  ON media_assets(user_id, channel_id, created_at);

CREATE INDEX IF NOT EXISTS idx_media_assets_user_status
  ON media_assets(user_id, status);

CREATE TRIGGER update_media_assets_updated_at
  BEFORE UPDATE ON media_assets
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
