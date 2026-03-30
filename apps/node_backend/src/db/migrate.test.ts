import { describe, it, expect, vi } from 'vitest';

// Mock the database pool so importing migrate.ts does not require a live
// database connection (the pool is initialized at module load time).
vi.mock('./index.js', () => ({
  default: {
    query: vi.fn(),
    connect: vi.fn(),
    end: vi.fn(),
  },
}));

import { adaptMigrationForSqlite } from './migrate.js';

// ---------------------------------------------------------------------------
// adaptMigrationForSqlite – unit tests
// ---------------------------------------------------------------------------

describe('adaptMigrationForSqlite', () => {
  // -------------------------------------------------------------------------
  // Comment stripping
  // -------------------------------------------------------------------------

  it('strips leading -- comment lines so they are not sent to Turso', () => {
    const sql = `
-- Migration: Create foo
-- Version: 001
CREATE TABLE foo (id INTEGER PRIMARY KEY);
`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('--');
    expect(stmts[0]).toMatch(/CREATE TABLE foo/i);
  });

  it('strips inline -- comments after SQL code', () => {
    const sql = `CREATE TABLE foo (id INTEGER PRIMARY KEY); -- this is a comment\n`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('--');
  });

  it('strips /* */ block comments', () => {
    const sql = `/* block comment */ CREATE TABLE foo (id INTEGER PRIMARY KEY);`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('/*');
    expect(stmts[0]).toMatch(/CREATE TABLE foo/i);
  });

  it('does not split on semicolons inside -- comments', () => {
    // The comment contains a semicolon that must not create a spurious statement
    const sql = `
-- DROP TABLE IF EXISTS old_foo;
CREATE TABLE foo (id INTEGER PRIMARY KEY);
`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).toMatch(/CREATE TABLE foo/i);
  });

  // -------------------------------------------------------------------------
  // PostgreSQL-only statement filtering
  // -------------------------------------------------------------------------

  it('skips CREATE EXTENSION statements', () => {
    const sql = `
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE foo (id TEXT PRIMARY KEY);
`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).toMatch(/CREATE TABLE foo/i);
  });

  it('skips trigger EXECUTE FUNCTION statements', () => {
    const sql = `
CREATE TABLE foo (id TEXT PRIMARY KEY);
CREATE TRIGGER trg BEFORE UPDATE ON foo FOR EACH ROW EXECUTE FUNCTION my_fn();
`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).toMatch(/CREATE TABLE foo/i);
  });

  it('removes CREATE OR REPLACE FUNCTION ... $$ ... $$ LANGUAGE plpgsql blocks', () => {
    const sql = `
CREATE TABLE foo (id TEXT PRIMARY KEY);
CREATE OR REPLACE FUNCTION update_ts()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE INDEX idx_foo ON foo(id);
`;
    const stmts = adaptMigrationForSqlite(sql);
    // Only CREATE TABLE and CREATE INDEX should survive
    expect(stmts.some((s) => /CREATE TABLE foo/i.test(s))).toBe(true);
    expect(stmts.some((s) => /CREATE INDEX idx_foo/i.test(s))).toBe(true);
    expect(stmts.some((s) => /FUNCTION/i.test(s))).toBe(false);
  });

  // -------------------------------------------------------------------------
  // PostgreSQL → SQLite type/function replacements
  // -------------------------------------------------------------------------

  it('replaces gen_random_uuid() with a randomblob UUID expression', () => {
    const sql = `CREATE TABLE t (id TEXT DEFAULT gen_random_uuid());`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('gen_random_uuid');
    expect(stmts[0]).toContain('randomblob');
  });

  it('replaces NOW() with CURRENT_TIMESTAMP', () => {
    const sql = `CREATE TABLE t (ts TIMESTAMP DEFAULT NOW());`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('NOW()');
    expect(stmts[0]).toContain('CURRENT_TIMESTAMP');
  });

  it('replaces SERIAL with INTEGER', () => {
    const sql = `CREATE TABLE t (id SERIAL PRIMARY KEY);`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toContain('SERIAL');
    expect(stmts[0]).toContain('INTEGER');
  });

  it('replaces JSONB with TEXT (case-insensitive)', () => {
    const sql = `CREATE TABLE t (data JSONB NOT NULL);`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
    expect(stmts[0]).not.toMatch(/JSONB/i);
    expect(stmts[0]).toContain('TEXT');
  });

  // -------------------------------------------------------------------------
  // Multi-statement splitting
  // -------------------------------------------------------------------------

  it('splits multiple statements correctly', () => {
    const sql = `
CREATE TABLE foo (id TEXT PRIMARY KEY);
CREATE INDEX idx_foo ON foo(id);
CREATE INDEX idx_foo2 ON foo(id);
`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(3);
  });

  it('filters out empty or whitespace-only pieces after splitting', () => {
    const sql = `CREATE TABLE foo (id TEXT PRIMARY KEY);\n\n\n`;
    const stmts = adaptMigrationForSqlite(sql);
    expect(stmts).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Full migration file: 002_create_oauth_connections.sql
  // This test reproduces the exact production failure described in the bug
  // report (SQL_PARSE_ERROR: near EXISTS, "None": syntax error at (6, 43)).
  // -------------------------------------------------------------------------

  it('correctly adapts 002_create_oauth_connections.sql for Turso', () => {
    const migration002 = `-- Migration: Create oauth_connections table
-- Description: OAuth provider connections linked to users
-- Version: 002
-- Date: 2026-03-24

CREATE TABLE IF NOT EXISTS oauth_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(50) NOT NULL,
  provider_user_id VARCHAR(255) NOT NULL,
  access_token TEXT,
  refresh_token TEXT,
  expires_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(provider, provider_user_id)
);

-- Create indexes for faster queries
CREATE INDEX idx_oauth_user_id ON oauth_connections(user_id);
CREATE INDEX idx_oauth_provider ON oauth_connections(provider);
CREATE INDEX idx_oauth_provider_user ON oauth_connections(provider, provider_user_id);
`;

    const stmts = adaptMigrationForSqlite(migration002);

    // Should produce exactly 4 statements (CREATE TABLE + 3 CREATE INDEX)
    expect(stmts).toHaveLength(4);

    const createTable = stmts[0];
    // No comment lines – the root cause of the Turso SQL_PARSE_ERROR
    expect(createTable).not.toContain('--');
    // gen_random_uuid() replaced
    expect(createTable).not.toContain('gen_random_uuid');
    expect(createTable).toContain('randomblob');
    // NOW() replaced
    expect(createTable).not.toContain('NOW()');
    expect(createTable).toContain('CURRENT_TIMESTAMP');
    // Statement starts cleanly with CREATE TABLE
    expect(createTable.trimStart()).toMatch(/^CREATE TABLE IF NOT EXISTS oauth_connections/i);

    // Index statements are present
    expect(stmts[1]).toMatch(/CREATE INDEX idx_oauth_user_id/i);
    expect(stmts[2]).toMatch(/CREATE INDEX idx_oauth_provider\b/i);
    expect(stmts[3]).toMatch(/CREATE INDEX idx_oauth_provider_user/i);
  });

  // -------------------------------------------------------------------------
  // Full migration file: 001_create_users.sql
  // -------------------------------------------------------------------------

  it('correctly adapts 001_create_users.sql for Turso', () => {
    const migration001 = `-- Migration: Create users table
-- Description: Core users table with UUID-based identity
-- Version: 001
-- Date: 2026-03-24

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX idx_users_created_at ON users(created_at);

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
`;

    const stmts = adaptMigrationForSqlite(migration001);

    // CREATE EXTENSION × 2 skipped, FUNCTION block stripped, EXECUTE FUNCTION trigger skipped
    // Remaining: CREATE TABLE + CREATE INDEX = 2 statements
    expect(stmts).toHaveLength(2);
    expect(stmts[0]).toMatch(/CREATE TABLE IF NOT EXISTS users/i);
    expect(stmts[1]).toMatch(/CREATE INDEX idx_users_created_at/i);
    // No comments in output
    expect(stmts.every((s) => !s.includes('--'))).toBe(true);
  });
});
