# Fix 500 Error on GET /api/config/nodes/:nodeId/agents

## Background

### Context

The endpoint `GET /api/config/nodes/:nodeId/agents?sourcePlatform=openclaw` calls
`listOpenClawRuntimeAgents(nodeId)`, which runs the `openclaw` CLI via `execFileAsync`.

### Problem

If the `openclaw` binary is absent from the server's PATH (i.e. the plugin is not
installed), `execFileAsync` throws an `ENOENT` system error. This propagates
uncaught out of `listOpenClawRuntimeAgents`, reaches the route's catch block, and
the API returns HTTP 500.

Any other CLI failure (non-zero exit code, timeout, invalid JSON output) similarly
throws an unhandled error and produces a 500.

### Motivation

A missing or temporarily unavailable `openclaw` binary should not crash the API.
The correct behaviour is to return an empty agent list with HTTP 200, so the client
can render gracefully (e.g. show an empty list or a "not connected" indicator)
without an error page.

## Goals

- Return `[]` instead of throwing when `openclaw` is not installed (`ENOENT`).
- Return `[]` instead of throwing when the CLI exits with a non-zero code.
- Return `[]` instead of throwing when the CLI output is invalid JSON.
- Keep the happy-path behaviour unchanged.
- Add tests covering the error cases.

## Implementation Plan

1. **Harden `listOpenClawRuntimeAgents`** in
   `apps/node_backend/src/services/openclawAgentRuntimeService.ts`:
   - Wrap the `execFileAsync` call in a try/catch.
   - On `ENOENT` (binary not found): log a debug-level notice and return `[]`.
   - On any other error (non-zero exit, timeout, maxBuffer exceeded): log a
     `console.error` with the error details and return `[]`.
   - Wrap `JSON.parse` in a try/catch; on invalid JSON log and return `[]`.

2. **Add unit tests** for the new error paths in a new file
   `apps/node_backend/src/services/openclawAgentRuntimeService.test.ts`:
   - `ENOENT` → returns `[]`.
   - Non-zero exit code → returns `[]`.
   - Invalid JSON stdout → returns `[]`.
   - Valid JSON stdout → returns normalized agents (existing happy-path).

## Acceptance Criteria

- `GET /api/config/nodes/:nodeId/agents?sourcePlatform=openclaw` returns HTTP 200
  with `{ agents: [] }` when the `openclaw` binary is not installed.
- `GET /api/config/nodes/:nodeId/agents?sourcePlatform=openclaw` returns HTTP 200
  with `{ agents: [] }` when the `openclaw` CLI exits with a non-zero code.
- The endpoint continues to return the agent list normally when `openclaw` succeeds.
- Existing route tests (`config.test.ts`) continue to pass.
- New service-level unit tests cover all three error cases.

## Validation Commands

- `cd apps/node_backend && npx vitest run src/services/openclawAgentRuntimeService.test.ts`
- `cd apps/node_backend && npx vitest run src/routes/config.test.ts`
