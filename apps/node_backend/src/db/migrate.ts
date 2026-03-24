import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from './index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

interface Migration {
  version: string;
  filename: string;
  sql: string;
}

// Create migrations tracking table
async function createMigrationsTable(): Promise<void> {
  const query = `
    CREATE TABLE IF NOT EXISTS migrations (
      id SERIAL PRIMARY KEY,
      version VARCHAR(10) NOT NULL UNIQUE,
      filename VARCHAR(255) NOT NULL,
      applied_at TIMESTAMP DEFAULT NOW()
    );
  `;
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

    // Execute migration SQL
    await client.query(migration.sql);

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
