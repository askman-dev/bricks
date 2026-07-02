-- Migration: Add channel site publish commit tracking
-- Description: Store the git commit used by the latest publish attempt and latest successful public release.
-- Version: 029
-- Date: 2026-07-02

ALTER TABLE channel_sites
  ADD COLUMN IF NOT EXISTS latest_publish_commit_sha VARCHAR(64);

ALTER TABLE channel_sites
  ADD COLUMN IF NOT EXISTS published_commit_sha VARCHAR(64);
