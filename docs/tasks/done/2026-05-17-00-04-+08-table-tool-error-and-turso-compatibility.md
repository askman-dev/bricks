# Table Tool Error and Turso Compatibility Fix

## Background

The historical chat stream can show a `table_create` tool call stuck in the
"calling" state. Database inspection showed two different failure modes in the
same assistant response:

- The first `table_create` call returned a normal tool result with
  `ok: false` because the model omitted the required `resourceId` argument.
- The second `table_create` call had valid arguments, but no persisted
  `tool_call` result row. A direct non-mutating SQL probe showed the underlying
  `createTable` query fails on Turso/libSQL because it uses PostgreSQL's
  `NOW()` function.

The UI difference comes from persistence, not from user intent. Business-level
tool failures are persisted as result rows, while thrown tool execution errors
from the AI SDK stream are currently ignored by the backend stream wrapper.

## Goals

- Make asset table mutations compatible with the repository's Turso/libSQL
  production database.
- Persist tool execution errors so tool starts cannot remain permanently stuck
  in `dispatched`.
- Preserve clear UX semantics: started, completed successfully, completed with
  business failure, and completed with execution error should be distinguishable
  in history.
- Add focused regression coverage for both the SQL compatibility issue and the
  missing `tool-error` persistence path.

## Implementation Plan

1. Fix Turso-compatible asset table writes.
   - Replace PostgreSQL-only timestamp expressions in asset table write paths
     with SQL that works under Turso/libSQL.
   - Audit nearby table, column, and row mutation queries for other
     PostgreSQL-only functions or syntax.
   - Keep existing PostgreSQL behavior working if the service is still run with
     a PostgreSQL `DATABASE_URL`.

2. Persist AI SDK tool execution errors.
   - Extend the stream event model in `apps/node_backend/src/llm/llm_service.ts`
     to handle `tool-error` parts from `result.fullStream`.
   - Route tool execution errors through a callback with the same step and call
     identity used by `tool-call` start messages.
   - Upsert a tool result/error message for the failed step and mark the
     matching `:tc:<step>:<call>` start message as completed or failed instead
     of leaving it `dispatched`.

3. Recheck step/call identity handling.
   - Confirm `onToolCallStart`, `onStepFinish`, and any new error callback use a
     single consistent source of step and call indexes.
   - Avoid creating synthetic completed rows with IDs that do not match the
     original start row.

4. Update tests.
   - Add or extend backend tests for `table_create` against the Turso dialect or
     a SQL conversion path that catches SQLite-incompatible expressions.
   - Add a stream wrapper test where the SDK emits `tool-call`, then
     `tool-error`, then final text, and assert that the persisted history has no
     permanently dispatched start row.
   - Add a route-level regression test if needed to verify the message IDs and
     task states shown to clients.

5. Validate with realistic data.
   - Reproduce the historical `show me a table` scenario locally with a fixture
     or test database.
   - Confirm the UI/history shows a completed error state rather than a stale
     "calling" row if execution fails.
   - Confirm a valid `table_create` request creates or updates an asset table in
     Turso/libSQL.

6. Update documentation and maps.
   - Keep the Turso compatibility note in `docs/kb/`.
   - Update code maps if implementation changes feature entry points, backend
     tool logic, or validation indexes.

## Acceptance Criteria

- A valid `table_create` call with `resourceId` and `title` succeeds against
  Turso/libSQL and leaves an `asset_tables` row.
- A `table_create` execution error is visible in chat history as a completed or
  failed tool event, not as an indefinitely "calling" event.
- The first invalid-arguments failure still appears as a normal tool result with
  the returned `invalid_args` payload.
- Message ordering remains deterministic for tool start, tool result/error, and
  final assistant text.
- Tests cover the Turso SQL compatibility bug and the AI SDK `tool-error`
  persistence bug.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test -- --run src/services/localAgentLoopService.test.ts`
- `cd apps/node_backend && npm test -- --run src/routes/chat.test.ts`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test`
- `cd apps/mobile_chat_app && flutter analyze`
