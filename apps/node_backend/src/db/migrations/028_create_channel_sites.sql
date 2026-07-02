-- Migration: Create channel sites
-- Description: Channel-scoped static website metadata and public slug binding.
-- Version: 028
-- Date: 2026-06-30

CREATE TABLE IF NOT EXISTS channel_sites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id VARCHAR(255) NOT NULL,
  public_slug VARCHAR(63) NOT NULL UNIQUE,
  latest_build_status VARCHAR(32) NOT NULL DEFAULT 'not_built' CHECK (latest_build_status IN ('not_built', 'succeeded', 'failed')),
  latest_build_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (user_id, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_channel_sites_slug
  ON channel_sites(public_slug);

CREATE INDEX IF NOT EXISTS idx_channel_sites_user_channel
  ON channel_sites(user_id, channel_id);

CREATE TRIGGER update_channel_sites_updated_at
  BEFORE UPDATE ON channel_sites
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
