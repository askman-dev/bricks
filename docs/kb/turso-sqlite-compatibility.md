# Turso / SQLite Compatibility Notes

## Purpose

Production data can run on Turso/libSQL through `TURSO_DATABASE_URL`. Backend
SQL must therefore stay compatible with SQLite semantics unless a query is
explicitly guarded by the active database dialect.

This note records compatibility issues that can produce runtime-only failures
even when TypeScript and route tests pass.

## Known Issue: PostgreSQL Timestamp Functions

Do not use PostgreSQL-only functions such as `NOW()` in SQL that may execute
against Turso/libSQL.

Example failure observed while debugging `table_create`:

```text
SQL_INPUT_ERROR: SQLite input error: no such function: NOW
```

The failing pattern was:

```sql
ON CONFLICT (user_id, resource_id)
DO UPDATE SET title = EXCLUDED.title, updated_at = NOW()
```

Under Turso/libSQL, use a SQLite-compatible timestamp expression or branch by
`pool.dialect`.

## Practical Rules

- Treat `apps/node_backend/src/db/index.ts` as the source of truth for the
  active dialect.
- If SQL is shared by PostgreSQL and Turso, avoid database-specific functions.
- If dialect-specific SQL is necessary, branch explicitly on `pool.dialect` and
  keep both branches covered by tests.
- Prefer integration-style probes for mutation queries that are hard to validate
  through unit tests alone.
- When a tool start is persisted before execution, any thrown SQL/runtime error
  must also be persisted as a tool error so the UI does not show a stale
  "calling" state.

## Offline Validation Options

Use offline checks before reaching for a remote Turso database:

1. Mock the repository database pool with `pool.dialect = 'turso'` in focused
   unit tests. Assert generated runtime SQL uses SQLite-compatible expressions
   such as `CURRENT_TIMESTAMP`, `json_patch(...)`, and does not contain
   PostgreSQL-only syntax such as `NOW()` or `::jsonb`.
2. Use the existing migration adapter tests around `adaptMigrationForSqlite` for
   migration files. This catches migration-only PostgreSQL syntax, but it does
   not validate runtime service SQL.
3. For stronger no-network execution coverage, create a temporary local
   libSQL/SQLite file database through `@libsql/client` with a `file:` URL, run
   adapted migrations, execute the service function, then delete the temporary
   file. This can catch real execution errors such as `no such function: NOW`.
4. SQLite CLI checks are useful for broad SQL syntax probes, but prefer local
   `@libsql/client` tests when validating code that normally runs through the
   Turso client path.

## Review Checklist

When adding or changing backend SQL, check:

1. Does the query use PostgreSQL-only functions such as `NOW()`?
2. Does the query use syntax that SQLite/libSQL does not support?
3. Is the query executed through `pool.query`, meaning it may hit either
   PostgreSQL or Turso?
4. Is there coverage or a local probe for the Turso/libSQL path?
5. If the query runs inside an AI tool, will thrown execution errors be visible
   in chat history?
