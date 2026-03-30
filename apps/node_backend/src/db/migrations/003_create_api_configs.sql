-- Migration: Create api_configs table
-- Description: User API configurations with encryption support
-- Version: 003
-- Date: 2026-03-24

CREATE TABLE IF NOT EXISTS api_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category VARCHAR(50) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  config JSONB NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_api_configs_user_id ON api_configs(user_id);
CREATE INDEX idx_api_configs_category ON api_configs(category);
CREATE INDEX idx_api_configs_provider ON api_configs(provider);
CREATE INDEX idx_api_configs_default ON api_configs(is_default) WHERE is_default = TRUE;

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_api_configs_updated_at
  BEFORE UPDATE ON api_configs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add constraint to ensure only one default per user per category
CREATE UNIQUE INDEX idx_api_configs_one_default_per_user_category
  ON api_configs(user_id, category)
  WHERE is_default = TRUE;
