# SSE Topology Refresh Rate Limit

## Background

Manual browser testing showed repeated `429 Too Many Requests` errors for
`/api/chat/scopes`, `/api/chat/channel-names`, and `/api/chat/scope-settings`.
The frontend refreshed scope topology after every SSE snapshot, and each refresh
fans out to three HTTP requests.

## Goals

- Keep channel/thread topology updates after tool-created or tool-renamed
  scopes.
- Avoid repeated topology refreshes during streaming snapshots.
- Preserve local manual test usability without hitting sync rate limits.

## Implementation Plan

1. Detect terminal task snapshots from SSE messages.
2. Refresh topology at most once per completed/failed/cancelled task id.
3. Keep the existing refresh method for manual or future explicit calls.
4. Rebuild the local manual test frontend and verify 429s stop.

## Acceptance Criteria

- A streaming task no longer triggers topology refresh on every SSE snapshot.
- A task that reaches a terminal state can still refresh channel/thread lists.
- Local manual testing can stay open without repeatedly hitting the sync rate
  limit.

## Validation Commands

- `cd apps/mobile_chat_app && flutter analyze`
- `cd apps/mobile_chat_app && flutter build web --debug --dart-define=BRICKS_API_BASE_URL=http://127.0.0.1:3011 --dart-define=BRICKS_TEST_TOKEN="$BRICKS_TEST_TOKEN"`
