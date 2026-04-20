# Background
Users report three chat issues: (1) `default` route replies can be truncated, (2) `default` route should support streaming output, and (3) `openclaw` may also support progressive output (observed via Telegram), while the project prefers a simple solution decoupled from OpenClaw internals.

# Goals
1. Ensure full assistant text is persisted/visible for `default` route (avoid obvious truncation caused by low token cap).
2. Add streaming response support for `default` route in the chat path.
3. Keep `openclaw` flow unchanged/decoupled while documenting feasible progressive-delivery options.
4. Preserve "persist user message first" behavior and graceful failure semantics.

# Implementation Plan (phased)
## Phase 1: Backend chat streaming endpoint (default route only)
- Add `/api/chat/respond/stream` SSE endpoint in `apps/node_backend/src/routes/chat.ts`.
- Reuse existing task acceptance + user message persistence path before model invocation.
- For `default` router: stream deltas from `streamWithUserConfig`, accumulate text server-side, persist final assistant message, send `done` event with `lastSeqId`.
- For `openclaw` router: return validation error from this endpoint to keep separation of concerns.

## Phase 2: Truncation mitigation
- Add optional `maxTokens` parsing in chat respond routes.
- Increase LLM service fallback max output tokens from 1024 to 4096 when caller does not specify.

## Phase 3: Mobile client integration
- Add SSE parsing support in `ChatHistoryApiService` for `/api/chat/respond/stream`.
- Update `chat_screen.dart` send flow:
  - use streaming endpoint for effective `default` router
  - keep existing async `/respond` call path for `openclaw`
- Keep UI update loop simple: append streamed deltas to placeholder assistant bubble and mark completed on done.

## Phase 4: Validation
- Update/extend route tests for new streaming endpoint semantics.
- Run targeted backend tests.

# Acceptance Criteria
- `default` route supports visible progressive output in app UI and persists full assistant text on completion.
- `default` route no longer relies on a 1024-token implicit cap when max tokens are unspecified.
- `openclaw` route behavior remains asynchronous and unaffected by the new default streaming path.
- If model generation fails, user message remains persisted and UI shows failure.
