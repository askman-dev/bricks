-- Migration: Create platform_nodes table
-- Description: Persist per-user node definitions that own plugin identifiers for platform token scoping.

CREATE TABLE IF NOT EXISTS platform_nodes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  node_id VARCHAR(64) NOT NULL,
  display_name VARCHAR(128) NOT NULL,
  plugin_id VARCHAR(128) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, node_id),
  UNIQUE (user_id, plugin_id)
);

CREATE INDEX IF NOT EXISTS idx_platform_nodes_user_id
  ON platform_nodes(user_id);

CREATE TRIGGER update_platform_nodes_updated_at
  BEFORE UPDATE ON platform_nodes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
