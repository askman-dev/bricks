# Platform ack scaling and dialect cleanup

## Problem

Two follow-up issues remain in the platform ack path:

1. The Turso/libSQL ack update builds a large `OR` predicate with two bind
   parameters per acked message and the `/api/v1/platform/events/ack` route
   does not currently cap `ackedEventIds`.
2. `platformIntegrationService.ts` re-reads `process.env.TURSO_DATABASE_URL`
   even though the DB module already selects the active pool/dialect.

## Approach

- Add a clear server-side batch cap for `ackedEventIds`, aligned with the
  platform events page-size limit.
- Chunk Turso ack updates into smaller SQL statements so large valid batches do
  not build oversized statements.
- Expose DB dialect metadata from the DB module and branch on that instead of
  duplicating env-var checks in service code.
- Add/adjust backend tests for route validation, Turso SQL chunking, and
  dialect-driven behavior.

## Validation

- `cd apps/node_backend && npm test -- --run src/routes/platform.test.ts src/services/platformIntegrationService.test.ts`
- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm run build`

## Notes

- This task is a follow-up to review feedback after the OpenClaw/platform
  handoff work already merged.
- The intended PR should be a fresh branch from latest `main`.
