# Background
After page refresh, the chat view currently loads the full channel/session history and does not automatically scroll to the latest message. This causes heavy initial rendering for long sessions and makes users manually drag the scroll bar to reach the newest content.

# Goals
- Limit initial history load to only the latest 100 messages for the active session/channel.
- Ensure the message list defaults to showing the newest message (bottom) after refresh/load.
- Keep behavior compatible with existing incremental sync and persistence paths.

# Implementation Plan (phased)
## Phase 1: Backend and API client load window
1. Add optional `limit` support to `GET /api/chat/history/:sessionId`.
2. Add optional `limit` support to `syncMessages` service, applying it safely only for full-history requests (`afterSeq == 0`) by selecting the newest N messages then restoring chronological order.
3. Update Flutter `ChatHistoryApiService.load` to send `?limit=100` by default.

## Phase 2: UI default-to-latest behavior
1. Convert message list widget to stateful with an internal `ScrollController`.
2. Auto-scroll to bottom after first frame and when message count changes.
3. Keep behavior smooth and safe when list is not yet attached.

## Phase 3: Validation
1. Add/adjust unit test(s) to verify client history request includes the load window.
2. Run repository bootstrap and targeted tests.

# Acceptance Criteria
- On refresh, history endpoint is requested with a limit of 100 messages.
- UI initially lands at the latest message without manual scrolling.
- Existing chat history API service tests pass after change.
- Validation commands are run and documented (`./tools/init_dev_env.sh`, `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart`).
