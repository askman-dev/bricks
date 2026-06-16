# Local Cloud DB Debug Mode

## Background

The backend can start with Turso credentials from `.env.local`, but the Express
app middleware always runs migrations before serving requests. That makes local
debug sessions against the production Turso database risky and can also block
simple health checks when the remote migration request times out.

## Goals

- Allow local backend requests to skip migrations when `AUTO_MIGRATE=false`.
- Keep the existing migration behavior unchanged when the flag is absent.
- Preserve the existing Flutter test-token quick login flow for local web
  testing against a local API.

## Implementation Plan

1. Update the Express migration middleware to treat `AUTO_MIGRATE=false` as an
   explicit request to skip migrations.
2. Add focused backend coverage for the skip behavior.
3. Validate that the backend can start against Turso and serve `/api/health`
   with migrations disabled.

## Acceptance Criteria

- A local backend started with `AUTO_MIGRATE=false` serves `/api/health` without
  attempting to run migrations.
- Existing request-time migration behavior remains active when
  `AUTO_MIGRATE` is not set to `false`.
- Flutter web can be launched with `BRICKS_API_BASE_URL` and
  `BRICKS_TEST_TOKEN` from `.env.local`.

## Validation Commands

- `npm test -- src/app.test.ts`
- `AUTO_MIGRATE=false npm run dev`
- `curl http://localhost:3010/api/health`
