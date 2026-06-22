# PR 266 Review Follow-up

## Background

PR #266 added `table.batch_add_rows` for the Node backend, but the review found a few gaps in the tool wiring and payload handling. The follow-up should stay narrowly focused on the review feedback so the original feature remains intact while the agent tool schema, sanitization behavior, and regression coverage are completed.

## Goals

- Expose `table.batch_add_rows` through the agent tool builder with a documented row payload shape.
- Sanitize batch row payloads consistently in both the internal tool path and the REST route.
- Add targeted tests for the reviewed batch-tool and batch-route behaviors.

## Implementation Plan

1. Update `localAgentLoopService.ts` to add a dedicated batch-row sanitization helper, use it in the `table.batch_add_rows` dispatch path, and expose the corresponding `table_batch_add_rows` tool definition in `buildAgentTools`.
2. Update `resources.ts` so the batch rows route sanitizes each row item before delegating to `batchAddRows`.
3. Extend the existing Vitest coverage for `localAgentLoopService.test.ts` and `resources.test.ts` to cover batch-tool exposure, batch dispatch validation, and row-value sanitization.
4. Re-run targeted Node backend tests, then run final automated review/security validation for the PR diff.

## Acceptance Criteria

- The agent tool set includes `table_batch_add_rows` with a schema that requires `resourceId` and a 2–10 item `rows` array.
- The internal batch tool dispatch sanitizes each row payload before calling `batchAddRows`, including the documented `{ cellData: ... }` shape.
- The batch rows REST route coerces number/boolean values to strings, preserves nulls, and drops nested objects/arrays before calling `batchAddRows`.
- Targeted backend tests cover the reviewed batch tool and route behaviors and pass successfully.

## Validation Commands

- `cd /home/runner/work/bricks/bricks/apps/node_backend && npm test -- src/services/localAgentLoopService.test.ts src/routes/resources.test.ts`
