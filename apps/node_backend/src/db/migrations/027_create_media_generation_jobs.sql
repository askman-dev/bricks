-- Migration: Create media generation jobs
-- Description: Durable provider-side image and video generation job records.
-- Version: 027
-- Date: 2026-06-30

CREATE TABLE IF NOT EXISTS media_generation_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  thread_id VARCHAR(255),
  kind VARCHAR(32) NOT NULL CHECK (kind IN ('image', 'video')),
  status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
  prompt TEXT NOT NULL,
  input_media_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  provider VARCHAR(64) NOT NULL,
  model VARCHAR(255) NOT NULL,
  provider_operation_name TEXT,
  result_media_id UUID REFERENCES media_assets(id) ON DELETE SET NULL,
  error_text TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_generation_jobs_user_channel_created
  ON media_generation_jobs(user_id, channel_id, created_at);

CREATE INDEX IF NOT EXISTS idx_media_generation_jobs_user_status
  ON media_generation_jobs(user_id, status);

CREATE TRIGGER update_media_generation_jobs_updated_at
  BEFORE UPDATE ON media_generation_jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
