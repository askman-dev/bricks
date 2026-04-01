# Background
A production error occurs when updating API config in the Node backend with LibSQL/SQLite: `no such function: NOW`. The update statement in `configService.ts` still uses PostgreSQL-style `NOW()`.

# Goals
- Replace the non-portable timestamp function with SQLite-compatible SQL.
- Ensure the config update flow succeeds on LibSQL.
- Validate backend code still compiles/tests for the touched area.

# Implementation Plan (phased)
1. Locate the `updateApiConfig` SQL update statement using `updated_at = NOW()`.
2. Replace `NOW()` with `CURRENT_TIMESTAMP` in that query.
3. Run focused backend validation (`vitest` and/or type-check) to catch regressions.
4. Commit the plan and code change.

# Acceptance Criteria
- Updating API config no longer fails with `SQL_INPUT_ERROR: no such function: NOW`.
- `apps/node_backend/src/services/configService.ts` uses SQLite-compatible timestamp SQL for `updated_at`.
- Relevant backend validation command(s) complete successfully.
