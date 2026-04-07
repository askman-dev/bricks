# Background
A production migration (`006_create_chat_sessions.sql`) fails on Turso/libSQL with `SQL_PARSE_ERROR: bad variable name`. The failing statement includes PostgreSQL cast syntax in a default value (`'[]'::jsonb`), which survives adaptation as `'[]'::TEXT` and is still invalid SQLite syntax.

# Goals
1. Make migration adaptation robust for PostgreSQL cast syntax (`::type`) when running against SQLite/Turso.
2. Add regression coverage to prevent future migration failures from cast expressions.
3. Validate that migration adapter tests pass.

# Implementation Plan (phased)
## Phase 1: Adapter fix
- Update `adaptMigrationForSqlite` in `apps/node_backend/src/db/migrate.ts` to remove PostgreSQL `::type` cast fragments during SQLite adaptation.
- Keep existing replacements (`JSONB -> TEXT`, `NOW() -> CURRENT_TIMESTAMP`, etc.) unchanged.

## Phase 2: Regression tests
- Add a focused unit test in `apps/node_backend/src/db/migrate.test.ts` asserting cast removal behavior for expressions like `'[]'::jsonb`.
- Add/extend integration-like migration fixture test to ensure `006_create_chat_sessions.sql` style SQL is adapted to SQLite-safe output.

## Phase 3: Verification
- Run the node backend migration adapter unit tests.
- Confirm the adapted SQL no longer contains `::` casts.

# Acceptance Criteria
- `adaptMigrationForSqlite` output never includes PostgreSQL `::type` casts.
- A test explicitly verifies cast removal for `'[]'::jsonb`-style defaults.
- Relevant tests pass locally with Vitest.
