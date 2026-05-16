import pool from '../db/index.js';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

export interface AssetTable {
  id: string;
  userId: string;
  resourceId: string;
  title: string;
  createdAt: string;
  updatedAt: string;
}

export interface AssetTableColumn {
  id: string;
  resourceId: string;
  columnKey: string;
  displayName: string;
  columnOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface AssetTableRow {
  id: string;
  resourceId: string;
  displayNumber: number;
  cellData: Record<string, string | null>;
  isDeleted: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AssetTableDetail extends AssetTable {
  columns: AssetTableColumn[];
  rows: AssetTableRow[];
}

// ---------------------------------------------------------------------------
// Row mappers
// ---------------------------------------------------------------------------

interface TableRow {
  id: string;
  user_id: string;
  resource_id: string;
  title: string;
  created_at: string;
  updated_at: string;
}

interface ColumnRow {
  id: string;
  user_id: string;
  resource_id: string;
  column_key: string;
  display_name: string;
  column_order: number;
  created_at: string;
  updated_at: string;
}

interface DataRow {
  id: string;
  user_id: string;
  resource_id: string;
  display_number: number;
  cell_data: Record<string, string | null>;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
}

function tableToDto(row: TableRow): AssetTable {
  return {
    id: row.id,
    userId: row.user_id,
    resourceId: row.resource_id,
    title: row.title,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function columnToDto(row: ColumnRow): AssetTableColumn {
  return {
    id: row.id,
    resourceId: row.resource_id,
    columnKey: row.column_key,
    displayName: row.display_name,
    columnOrder: row.column_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function dataRowToDto(row: DataRow): AssetTableRow {
  return {
    id: row.id,
    resourceId: row.resource_id,
    displayNumber: row.display_number,
    cellData: row.cell_data ?? {},
    isDeleted: row.is_deleted,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ---------------------------------------------------------------------------
// Service functions – Tables
// ---------------------------------------------------------------------------

export async function listTables(userId: string): Promise<AssetTable[]> {
  const result = await pool.query<TableRow>(
    `SELECT id, user_id, resource_id, title, created_at, updated_at
       FROM asset_tables
      WHERE user_id = $1
      ORDER BY created_at ASC`,
    [userId],
  );
  return result.rows.map(tableToDto);
}

export async function createTable(
  userId: string,
  input: { resourceId: string; title: string },
): Promise<AssetTable> {
  const result = await pool.query<TableRow>(
    `INSERT INTO asset_tables (user_id, resource_id, title)
          VALUES ($1, $2, $3)
          ON CONFLICT (user_id, resource_id)
          DO UPDATE SET title = EXCLUDED.title, updated_at = NOW()
       RETURNING id, user_id, resource_id, title, created_at, updated_at`,
    [userId, input.resourceId, input.title],
  );
  return tableToDto(result.rows[0]);
}

export async function getTable(
  userId: string,
  resourceId: string,
): Promise<AssetTableDetail | null> {
  const [tableResult, colResult, rowResult] = await Promise.all([
    pool.query<TableRow>(
      `SELECT id, user_id, resource_id, title, created_at, updated_at
         FROM asset_tables
        WHERE user_id = $1 AND resource_id = $2`,
      [userId, resourceId],
    ),
    pool.query<ColumnRow>(
      `SELECT id, user_id, resource_id, column_key, display_name, column_order, created_at, updated_at
         FROM asset_table_columns
        WHERE user_id = $1 AND resource_id = $2
        ORDER BY column_order ASC, created_at ASC`,
      [userId, resourceId],
    ),
    pool.query<DataRow>(
      `SELECT id, user_id, resource_id, display_number, cell_data, is_deleted, created_at, updated_at
         FROM asset_table_rows
        WHERE user_id = $1 AND resource_id = $2 AND is_deleted = FALSE
        ORDER BY display_number ASC, created_at ASC`,
      [userId, resourceId],
    ),
  ]);

  if (!tableResult.rows[0]) return null;

  const columns = colResult.rows.map(columnToDto);
  const columnKeys = new Set(columns.map((c) => c.columnKey));

  // Strip orphan keys from cell_data so callers see only active columns.
  const rows = rowResult.rows.map((r) => {
    const filtered: Record<string, string | null> = {};
    for (const key of columnKeys) {
      filtered[key] = r.cell_data?.[key] ?? null;
    }
    return dataRowToDto({ ...r, cell_data: filtered });
  });

  return {
    ...tableToDto(tableResult.rows[0]),
    columns,
    rows,
  };
}

// ---------------------------------------------------------------------------
// Service functions – Columns
// ---------------------------------------------------------------------------

export async function addColumn(
  userId: string,
  resourceId: string,
  input: { columnKey: string; displayName: string; columnOrder?: number },
): Promise<AssetTableColumn> {
  const result = await pool.query<ColumnRow>(
    `INSERT INTO asset_table_columns (user_id, resource_id, column_key, display_name, column_order)
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (user_id, resource_id, column_key)
          DO UPDATE SET
            display_name = EXCLUDED.display_name,
            column_order = EXCLUDED.column_order,
            updated_at = NOW()
       RETURNING id, user_id, resource_id, column_key, display_name, column_order, created_at, updated_at`,
    [userId, resourceId, input.columnKey, input.displayName, input.columnOrder ?? 0],
  );
  return columnToDto(result.rows[0]);
}

export async function removeColumn(
  userId: string,
  resourceId: string,
  columnKey: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `DELETE FROM asset_table_columns
      WHERE user_id = $1 AND resource_id = $2 AND column_key = $3`,
    [userId, resourceId, columnKey],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}

// ---------------------------------------------------------------------------
// Service functions – Rows
// ---------------------------------------------------------------------------

export async function addRow(
  userId: string,
  resourceId: string,
  cellData: Record<string, string | null> = {},
): Promise<AssetTableRow> {
  // Assign display_number = MAX(display_number) + 1 for this resource.
  const result = await pool.query<DataRow>(
    `INSERT INTO asset_table_rows (user_id, resource_id, display_number, cell_data)
          SELECT $1, $2,
                 COALESCE((SELECT MAX(display_number) FROM asset_table_rows WHERE user_id = $1 AND resource_id = $2), 0) + 1,
                 $3::jsonb
       RETURNING id, user_id, resource_id, display_number, cell_data, is_deleted, created_at, updated_at`,
    [userId, resourceId, JSON.stringify(cellData)],
  );
  return dataRowToDto(result.rows[0]);
}

export async function updateRow(
  userId: string,
  resourceId: string,
  rowId: string,
  cellData: Record<string, string | null>,
): Promise<AssetTableRow | null> {
  // Merge incoming cell_data onto existing using JSONB concatenation operator (||).
  const result = await pool.query<DataRow>(
    `UPDATE asset_table_rows
        SET cell_data = cell_data || $4::jsonb,
            updated_at = NOW()
      WHERE user_id = $1 AND resource_id = $2 AND id = $3 AND is_deleted = FALSE
      RETURNING id, user_id, resource_id, display_number, cell_data, is_deleted, created_at, updated_at`,
    [userId, resourceId, rowId, JSON.stringify(cellData)],
  );
  return result.rows[0] ? dataRowToDto(result.rows[0]) : null;
}

export async function deleteRow(
  userId: string,
  resourceId: string,
  rowId: string,
): Promise<{ deleted: boolean }> {
  const result = await pool.query(
    `UPDATE asset_table_rows
        SET is_deleted = TRUE, updated_at = NOW()
      WHERE user_id = $1 AND resource_id = $2 AND id = $3`,
    [userId, resourceId, rowId],
  );
  return { deleted: (result.rowCount ?? 0) > 0 };
}
