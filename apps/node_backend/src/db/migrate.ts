import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from './index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const isTurso = Boolean(process.env.TURSO_DATABASE_URL);

// RFC 4122 v4 UUID expression for SQLite, using the built-in randomblob() function.
// Produces: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx  (y is one of 8, 9, a, b)
const SQLITE_UUID_EXPR =
  `(lower(hex(randomblob(4)))` +                                       // time_low    (8 hex)
  ` || '-' || lower(hex(randomblob(2)))` +                             // time_mid    (4 hex)
  ` || '-' || '4' || lower(substr(hex(randomblob(2)),2))` +            // version=4   (4 hex)
  ` || '-' || substr('89ab', 1 + (abs(random()) % 4), 1)` +           // RFC variant bit
  ` || lower(substr(hex(randomblob(2)),2))` +                          // clock_seq   (3 hex)
  ` || '-' || lower(hex(randomblob(6))))`;                             // node        (12 hex)

/**
 * Strip SQL line comments (-- ...) and block comments (/* ... *\/) from a
 * SQL string.  This must be done before splitting on semicolons so that:
 *   1. Semicolons inside comments do not create spurious empty statements.
 *   2. Comment-only preambles (present in all migration files) are not sent
 *      as standalone statements to Turso/libSQL, which can produce a
 *      SQL_PARSE_ERROR (e.g. "near EXISTS: syntax error") because the
 *      comment text gets prepended to the next real statement in the batch.
 */
function stripSqlComments(sql: string): string {
  // Remove block comments first (they may span lines and contain --)
  sql = sql.replace(/\/\*[\s\S]*?\*\//g, ' ');
  // Remove line comments
  sql = sql.replace(/--[^\n]*/g, '');
  return sql;
}

/**
 * Adapt a PostgreSQL migration SQL file to individual SQLite/Turso-compatible
 * statements.  Handles the most common PostgreSQL-isms present in this repo's
 * migration files:
 *   - SQL comments (-- and /* *\/) – stripped before splitting so they cannot
 *     confuse Turso's SQL parser or the semicolon-based statement splitter
 *   - CREATE EXTENSION (not supported in SQLite)
 *   - PL/pgSQL function definitions (dollar-quoted $$...$$)
 *   - Triggers that call EXECUTE FUNCTION (PostgreSQL-only trigger syntax)
 *   - ADD COLUMN IF NOT EXISTS → ADD COLUMN  (libSQL/Turso does not support the IF NOT EXISTS clause)
 *   - gen_random_uuid()  → SQLite randomblob UUID expression
 *   - SERIAL             → INTEGER
 *   - JSONB              → TEXT
 *   - NOW()              → CURRENT_TIMESTAMP
 *
 * Note: statements are split on top-level semicolons.  This is safe for the
 * migration files in this repo (no semicolons inside string literals), but
 * would need revisiting if future migrations contain string literals with ';'.
 */
export function adaptMigrationForSqlite(sql: string): string[] {
  // Remove PL/pgSQL function definitions ($$-quoted blocks) before stripping
  // comments, so that any -- or /* inside the function body is discarded
  // together with the whole block.
  sql = sql.replace(
    /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\b[\s\S]*?\$\$[\s\S]*?\$\$\s+LANGUAGE\s+\w+\s*;/gi,
    '',
  );

  // Strip comments before splitting on semicolons.  This prevents:
  //   - Comment preambles being sent as part of the first SQL statement to
  //     Turso, which triggers SQL_PARSE_ERROR on certain libSQL versions.
  //   - Semicolons inside comments creating spurious empty statements.
  sql = stripSqlComments(sql);

  const statements: string[] = [];

  for (let stmt of sql.split(';').map((s) => s.trim()).filter(Boolean)) {
    // Skip PostgreSQL-only DDL statements
    if (/\bCREATE\s+EXTENSION\b/i.test(stmt)) continue;
    if (/\bEXECUTE\s+FUNCTION\b/i.test(stmt)) continue;

    stmt = stmt.replace(/\bADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\b/gi, 'ADD COLUMN');
    stmt = stmt.replace(/\bgen_random_uuid\(\)/g, SQLITE_UUID_EXPR);
    stmt = stmt.replace(/\bSERIAL\b/g, 'INTEGER');
    stmt = stmt.replace(/\bJSONB\b/gi, 'TEXT');
    stmt = stmt.replace(/\bNOW\(\)/gi, 'CURRENT_TIMESTAMP');

    statements.push(stmt);
  }

  return statements;
}

interface Migration {
  version: string;
  filename: string;
  sql: string;
}

// Create migrations tracking table
async function createMigrationsTable(): Promise<void> {
  const query = isTurso
    ? `CREATE TABLE IF NOT EXISTS migrations (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         version TEXT NOT NULL UNIQUE,
         filename TEXT NOT NULL,
         applied_at TEXT DEFAULT (datetime('now'))
       )`
    : `CREATE TABLE IF NOT EXISTS migrations (
         id SERIAL PRIMARY KEY,
         version VARCHAR(10) NOT NULL UNIQUE,
         filename VARCHAR(255) NOT NULL,
         applied_at TIMESTAMP DEFAULT NOW()
       )`;
  await pool.query(query);
}

// Get applied migrations
async function getAppliedMigrations(): Promise<Set<string>> {
  const result = await pool.query('SELECT version FROM migrations ORDER BY version');
  return new Set(result.rows.map(row => row.version));
}

// Read migration files
async function readMigrations(): Promise<Migration[]> {
  const migrationsDir = path.join(__dirname, 'migrations');
  const files = await fs.readdir(migrationsDir);

  const migrations: Migration[] = [];

  for (const filename of files.sort()) {
    if (!filename.endsWith('.sql')) continue;

    const version = filename.split('_')[0];
    const filepath = path.join(migrationsDir, filename);
    const sql = await fs.readFile(filepath, 'utf-8');

    migrations.push({ version, filename, sql });
  }

  return migrations;
}

// Apply a single migration
async function applyMigration(migration: Migration): Promise<void> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    if (isTurso) {
      // SQLite/Turso: execute each statement individually after adaptation
      const statements = adaptMigrationForSqlite(migration.sql);
      for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i];
        try {
          await client.query(stmt);
        } catch (stmtError) {
          // Re-throw with statement context to make SQL parse failures easy to diagnose
          const msg = `Migration ${migration.filename}: statement ${i + 1}/${statements.length} failed.\nSQL: ${stmt}\nError: ${(stmtError as Error).message}`;
          throw Object.assign(new Error(msg), { cause: stmtError });
        }
      }
    } else {
      // PostgreSQL: execute the whole file as one batch
      await client.query(migration.sql);
    }

    // Record migration
    await client.query(
      'INSERT INTO migrations (version, filename) VALUES ($1, $2)',
      [migration.version, migration.filename]
    );

    await client.query('COMMIT');
    console.log(`✓ Applied migration ${migration.filename}`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

// Run all pending migrations
export async function runMigrations(): Promise<void> {
  console.log('Starting database migrations...');

  try {
    await createMigrationsTable();

    const appliedMigrations = await getAppliedMigrations();
    const allMigrations = await readMigrations();

    const pendingMigrations = allMigrations.filter(
      m => !appliedMigrations.has(m.version)
    );

    if (pendingMigrations.length === 0) {
      console.log('No pending migrations');
      return;
    }

    console.log(`Found ${pendingMigrations.length} pending migration(s)`);

    for (const migration of pendingMigrations) {
      await applyMigration(migration);
    }

    console.log('All migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

// Run migrations if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigrations()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
