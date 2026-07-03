import fs from 'node:fs/promises';
import path from 'node:path';
import { createClient, type Client, type InValue } from '@libsql/client';

type Row = Record<string, unknown>;

const DEFAULT_TABLES = [
  'migrations',
  'users',
  'oauth_connections',
  'api_configs',
  'oauth_states',
  'chat_tasks',
  'chat_messages',
  'chat_sync_checkpoints',
  'chat_scope_settings',
  'chat_channels',
  'platform_nodes',
  'chat_sessions',
];

const USER_SCOPED_TABLES = new Set([
  'chat_tasks',
  'chat_messages',
  'chat_sync_checkpoints',
  'chat_scope_settings',
  'chat_channels',
  'platform_nodes',
  'chat_sessions',
]);

function requiredEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function quoteIdent(value: string): string {
  return `"${value.replace(/"/g, '""')}"`;
}

function normalizeValue(value: unknown): InValue {
  if (value == null) return null;
  if (
    typeof value === 'string' ||
    typeof value === 'number' ||
    typeof value === 'bigint' ||
    typeof value === 'boolean'
  ) {
    return value;
  }
  if (value instanceof Date) return value;
  if (value instanceof ArrayBuffer) return value;
  if (value instanceof Uint8Array) return value;
  return JSON.stringify(value);
}

function fixtureDatabaseUrl(): string {
  const explicit = process.env.FIXTURE_DATABASE_URL?.trim();
  if (explicit) return explicit;
  const dbPath = path.resolve(process.cwd(), '.cache/chat-scroll-fixture.db');
  return `file:${dbPath}`;
}

function pathFromFileUrl(url: string): string | null {
  if (!url.startsWith('file:')) return null;
  const rawPath = url.slice('file:'.length);
  return path.resolve(rawPath);
}

async function removeExistingLocalDb(url: string): Promise<void> {
  const dbPath = pathFromFileUrl(url);
  if (!dbPath) return;
  await fs.mkdir(path.dirname(dbPath), { recursive: true });
  await Promise.all([
    fs.rm(dbPath, { force: true }),
    fs.rm(`${dbPath}-shm`, { force: true }),
    fs.rm(`${dbPath}-wal`, { force: true }),
  ]);
}

async function tableExists(client: Client, table: string): Promise<boolean> {
  const result = await client.execute({
    sql: "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = ? LIMIT 1",
    args: [table],
  });
  return result.rows.length > 0;
}

async function selectFixtureUserId(client: Client): Promise<string> {
  const explicit = process.env.FIXTURE_USER_ID?.trim();
  if (explicit) return explicit;

  const result = await client.execute(`
    SELECT user_id
      FROM chat_messages
     GROUP BY user_id
     ORDER BY MAX(COALESCE(write_seq, seq_id)) DESC
     LIMIT 1
  `);
  const userId = result.rows[0]?.user_id;
  if (typeof userId !== 'string' || userId.trim().length === 0) {
    throw new Error('Could not infer FIXTURE_USER_ID from chat_messages.');
  }
  return userId;
}

async function createLocalSchema(
  source: Client,
  dest: Client,
  tables: string[],
): Promise<void> {
  const placeholders = tables.map(() => '?').join(', ');
  const schema = await source.execute({
    sql: `
      SELECT type, name, tbl_name, sql
        FROM sqlite_schema
       WHERE sql IS NOT NULL
         AND name NOT LIKE 'sqlite_%'
         AND (
           (type = 'table' AND name IN (${placeholders}))
           OR (type IN ('index', 'trigger') AND tbl_name IN (${placeholders}))
         )
       ORDER BY
         CASE type
           WHEN 'table' THEN 0
           WHEN 'index' THEN 1
           WHEN 'trigger' THEN 2
           ELSE 3
         END,
         name
    `,
    args: [...tables, ...tables],
  });

  await dest.execute('PRAGMA foreign_keys = OFF');
  for (const row of schema.rows) {
    const sql = row.sql;
    if (typeof sql === 'string' && sql.trim().length > 0) {
      await dest.execute(sql);
    }
  }
}

async function columnNames(client: Client, table: string): Promise<string[]> {
  const result = await client.execute(`PRAGMA table_info(${quoteIdent(table)})`);
  return result.rows
    .map((row) => row.name)
    .filter((name): name is string => typeof name === 'string' && name.length > 0);
}

async function rowsForTable(
  client: Client,
  table: string,
  userId: string,
): Promise<Row[]> {
  if (table === 'migrations') {
    const result = await client.execute(`SELECT * FROM ${quoteIdent(table)} ORDER BY id`);
    return result.rows as Row[];
  }

  if (table === 'users') {
    const result = await client.execute({
      sql: `SELECT * FROM ${quoteIdent(table)} WHERE id = ?`,
      args: [userId],
    });
    return result.rows as Row[];
  }

  if (USER_SCOPED_TABLES.has(table)) {
    const orderBy = table === 'chat_messages'
      ? ' ORDER BY COALESCE(write_seq, seq_id), seq_id'
      : '';
    const result = await client.execute({
      sql: `SELECT * FROM ${quoteIdent(table)} WHERE user_id = ?${orderBy}`,
      args: [userId],
    });
    return result.rows as Row[];
  }

  return [];
}

async function insertRows(
  dest: Client,
  table: string,
  columns: string[],
  rows: Row[],
): Promise<void> {
  if (rows.length === 0) return;
  const placeholders = columns.map(() => '?').join(', ');
  const quotedColumns = columns.map(quoteIdent).join(', ');
  const sql = `INSERT INTO ${quoteIdent(table)} (${quotedColumns}) VALUES (${placeholders})`;

  await dest.execute('BEGIN');
  try {
    for (const row of rows) {
      const args: InValue[] = columns.map((column) => normalizeValue(row[column]));
      await dest.execute({
        sql,
        args,
      });
    }
    await dest.execute('COMMIT');
  } catch (error) {
    await dest.execute('ROLLBACK');
    throw error;
  }
}

async function main(): Promise<void> {
  const sourceUrl = requiredEnv('TURSO_DATABASE_URL');
  const sourceAuthToken = process.env.TURSO_AUTH_TOKEN?.trim();
  const destUrl = fixtureDatabaseUrl();

  await removeExistingLocalDb(destUrl);

  const source = createClient({
    url: sourceUrl,
    authToken: sourceAuthToken,
  });
  const dest = createClient({ url: destUrl });

  const existingTables = [];
  for (const table of DEFAULT_TABLES) {
    if (await tableExists(source, table)) {
      existingTables.push(table);
    }
  }

  if (!existingTables.includes('users') || !existingTables.includes('chat_messages')) {
    throw new Error('Remote database does not contain required users/chat_messages tables.');
  }

  const userId = await selectFixtureUserId(source);
  await createLocalSchema(source, dest, existingTables);

  const counts: Record<string, number> = {};
  for (const table of existingTables) {
    const columns = await columnNames(dest, table);
    const rows = await rowsForTable(source, table, userId);
    await insertRows(dest, table, columns, rows);
    counts[table] = rows.length;
  }

  await source.close();
  await dest.close();

  console.log(JSON.stringify({
    fixtureDatabaseUrl: destUrl,
    fixtureUserId: userId,
    copiedTables: counts,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
