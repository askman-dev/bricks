# Background

`/api/chat/sync/:sessionId` is currently consumed by fixed-interval short polling from the mobile chat app. When the conversation has pending async tasks (especially OpenClaw routing), this can generate many repeated requests with no new data and hit backend rate limits.

# Goals

1. Reduce unnecessary `/api/chat/sync` request frequency while preserving near-real-time updates.
2. Keep backward compatibility for existing clients that do not send long-poll parameters.
3. Add automated coverage for new long-poll behavior.

# Implementation Plan (phased)

## Phase 1: Backend long-poll support
- Add optional `waitMs` query parsing to `GET /api/chat/sync/:sessionId`.
- If no messages are available, keep the request open and retry sync checks until either:
  - new messages are found, or
  - `waitMs` timeout expires.
- Cap `waitMs` with a safe upper bound to avoid runaway request lifetimes.

## Phase 2: Client sync call upgrade
- Extend `ChatHistoryApiService.sync` to accept optional `waitMs` and append it to sync query parameters.
- Update chat screen sync loop to request long polling (bounded timeout) instead of pure short polling.

## Phase 3: Validation
- Update Node route tests to cover long-poll query parsing and bounded wait behavior.
- Update Flutter service tests to verify `waitMs` query transmission.
- Run targeted backend and Flutter tests.

# Acceptance Criteria

1. Chat sync endpoint accepts `waitMs` and does not block longer than the configured max bound.
2. Mobile chat sync requests include long-poll timeout for active scope polling.
3. Existing sync behavior remains compatible when `waitMs` is omitted.
4. Relevant route/service tests pass:
   - `npm test -- src/routes/chat.test.ts`
   - `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart`
