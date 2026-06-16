# Channel New UI Evidence Harness

## Background

The New Channel flow is user-visible and spans Flutter UI state, authenticated
API calls, and persisted `chat_channel_names` rows. A final screenshot alone is
not enough to diagnose failures because the same symptom can come from local UI
state, API persistence, database writes, or refresh-time hydration.

## Goals

- Provide one reusable command that validates the sidebar New Channel flow in a
  real browser against the local backend.
- Capture UI, API, and direct Turso database checkpoints so failures identify
  the broken layer.
- Store all generated evidence under ignored `.cache/` paths and keep secrets
  in `.env.local`.

## Implementation Plan

1. Add a `tools/evidence/channel_new_ui_harness/run.sh` entrypoint that loads
   `.env.local`, starts the backend and Flutter web server when needed, prepares
   local harness dependencies, and runs the browser validation.
2. Add a Playwright-based Node harness that performs Quick Login, opens the
   sidebar, creates a unique channel through the New Channel UI, checks API and
   Turso rows, reopens the sidebar, refreshes the page, and writes screenshots
   plus JSON checkpoint files.
3. Add a README documenting the single-command workflow, required environment
   variables, cloud-DB write behavior, evidence layout, and failure diagnosis.

## Acceptance Criteria

- Running `tools/evidence/channel_new_ui_harness/run.sh` produces a
  `summary.json` under `.cache/evidence/channel-new-ui/<run-id>/`.
- The harness records UI screenshots before creation, after creation, and after
  refresh.
- The harness records `/api/chat/channel-names` responses and a direct
  `chat_channel_names` query for the generated channel name.
- A passing run proves the New Channel sidebar flow displays immediately,
  persists through the API/database layer, survives sidebar reopen, and survives
  browser refresh.

## Validation Commands

- `tools/evidence/channel_new_ui_harness/run.sh`
- `test -f .cache/evidence/channel-new-ui/<run-id>/summary.json`
