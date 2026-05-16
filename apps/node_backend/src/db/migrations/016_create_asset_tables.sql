-- Migration: Create asset tables (JSONB sparse storage)
-- Description: Dynamic tables whose schema (columns) lives in a separate registry table,
-- so adding/removing columns is O(1) and never touches row data.

CREATE TABLE asset_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_id VARCHAR(255) NOT NULL,
  title TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, resource_id)
);

CREATE INDEX idx_asset_tables_user_id ON asset_tables(user_id);

CREATE TRIGGER update_asset_tables_updated_at
  BEFORE UPDATE ON asset_tables
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Column definitions (schema registry) – authoritative list of active columns.
-- Adding a column: INSERT here only. Removing: DELETE here; orphan keys in cell_data
-- are silently ignored at read time.
CREATE TABLE asset_table_columns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_id VARCHAR(255) NOT NULL,
  column_key VARCHAR(255) NOT NULL,
  display_name TEXT NOT NULL,
  column_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, resource_id, column_key)
);

CREATE INDEX idx_asset_table_columns_resource ON asset_table_columns(user_id, resource_id);

CREATE TRIGGER update_asset_table_columns_updated_at
  BEFORE UPDATE ON asset_table_columns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Row data – cell_data JSONB keys correspond to column_key values in asset_table_columns.
-- Keys absent from cell_data are treated as NULL (new column default).
-- Deleted rows are soft-deleted (is_deleted = true) so display_number stays stable.
CREATE TABLE asset_table_rows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resource_id VARCHAR(255) NOT NULL,
  display_number INT NOT NULL DEFAULT 0,
  cell_data JSONB NOT NULL DEFAULT '{}',
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_asset_table_rows_resource ON asset_table_rows(user_id, resource_id, is_deleted);

CREATE TRIGGER update_asset_table_rows_updated_at
  BEFORE UPDATE ON asset_table_rows
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
