# Background

Users observed chat history ordering where multiple assistant messages appear ahead of their corresponding user prompts after page refresh. The current history endpoint slices by recent write events (`write_seq`) and the client then re-sorts by `createdAt`, which can distort local chronology in long-running asynchronous sessions.

# Goals

1. Make `/api/chat/history/:sessionId` return a chronology-preserving window aligned with display ordering.
2. Keep incremental sync (`/api/chat/sync/:sessionId`) unchanged so write-cursor semantics remain stable.
3. Add regression tests for backend history behavior.

# Implementation Plan (phased)

## Phase 1: Backend history query alignment
- Add a dedicated service method for history retrieval that selects by `created_at` window and returns ascending `created_at` order.
- Update `/api/chat/history/:sessionId` route to use the new method instead of `syncMessages(...afterSeq=0...)`.

## Phase 2: Regression coverage
- Add service-level test to verify SQL ordering strategy for history.
- Add route-level test to verify `/history` calls the new service path.

## Phase 3: Code map maintenance
- Update logic map metadata/risk text to reflect the new history window strategy.

# Acceptance Criteria

1. `/api/chat/history/:sessionId` no longer depends on `write_seq`-window slicing for initial history loads.
2. Existing `/api/chat/sync/:sessionId` behavior remains cursor-based by `write_seq`.
3. Backend tests pass with new route/service coverage.
4. Logic map updated to capture the revised ordering risk and mitigation.

Validation commands:
- `cd apps/node_backend && npm test -- src/services/chatAsyncTransportService.test.ts src/routes/chat.test.ts`
