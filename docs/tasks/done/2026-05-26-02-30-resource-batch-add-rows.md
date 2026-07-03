# Resource Batch Add Rows

## Background

The Resource asset table system provides per-row CRUD operations (`table.add_row`, `table.update_row`, `table.delete_row`) exposed as AI agent tools and REST API endpoints. When an AI agent needs to populate a table with multiple rows (e.g., seeding structured data), it must call `table.add_row` once per row. This results in repeated round-trips that slow the agent loop.

### Problem

No batch insert operation exists. Multiple sequential `table.add_row` calls are the only option, which is inefficient when inserting 2–10 rows at once.

### Motivation

A single `table.batch_add_rows` call reduces agent tool-call count and network overhead when inserting a known list of rows.

## Goals

- Add a `batchAddRows` service function that inserts 2–10 rows in sequence and returns all inserted rows.
- Expose it as the AI tool `table.batch_add_rows` with array validation (length 2–10).
- Expose it as the REST endpoint `POST /api/resources/tables/:resourceId/rows/batch` with the same array constraints.
- Cover the new code with tests (SQL compatibility + route validation).

## Implementation Plan

1. **Service** (`assetTableService.ts`): Add `batchAddRows(userId, resourceId, cellDataArray)` that iterates the array and calls `addRow` sequentially, returning `AssetTableRow[]`. Sequential calls ensure each row atomically claims `MAX(display_number) + 1`.

2. **Tool constant & dispatch** (`localAgentLoopService.ts`):
   - Export `INTERNAL_TOOL_TABLE_BATCH_ADD_ROWS = 'table.batch_add_rows'`.
   - Append it to the `INTERNAL_TOOLS` array.
   - Add a `case` in `executeInternalTool` that validates `resourceId` (required string) and `rows` (array, length 2–10), sanitizes each item's `cellData`, then calls `batchAddRows`.

3. **REST route** (`resources.ts`):
   - Import `batchAddRows`.
   - Add `POST /tables/:resourceId/rows/batch` handler that validates `rows` is a non-empty array with 2–10 elements, sanitizes each `cellData`, and returns `201` with `{ rows }`.

4. **Tests**:
   - `assetTableService.test.ts`: Verify Turso-compatible SQL is issued for each `addRow` call within `batchAddRows` (JSON placeholder, no `::jsonb`, no `NOW()`).
   - `resources.test.ts`: Update mock to include `batchAddRows`; add tests for 200-path, `rows` length < 2, and `rows` length > 10.

## Acceptance Criteria

- Calling `table.batch_add_rows` with a `rows` array of 2–10 items inserts all rows and returns them in insertion order.
- Calling with fewer than 2 or more than 10 items returns `{ ok: false, error: { code: 'invalid_args' } }`.
- `POST /api/resources/tables/:resourceId/rows/batch` with a valid 2-row body returns HTTP 201 and `{ rows: [...] }`.
- The same endpoint returns HTTP 400 for an array of length 1 or length 11.
- All existing tests continue to pass.

## Validation Commands

- `cd apps/node_backend && npm test -- --reporter=verbose`
