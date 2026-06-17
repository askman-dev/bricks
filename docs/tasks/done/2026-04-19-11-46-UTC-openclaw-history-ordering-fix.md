# Background
Users reported incorrect chat history rendering when switching router to OpenClaw for one turn (with no OpenClaw server response yet), then switching back to the default router and sending another message. The delayed or pending OpenClaw assistant message can appear out of expected order in the message list.

# Goals
- Ensure chat history rendering is consistently ordered by message creation timestamp across mixed router usage.
- Prevent stale/pending OpenClaw task messages from disrupting visual chronology after switching routers.
- Add regression tests that cover unsorted backend payloads and verify stable chronological rendering expectations.

# Implementation Plan (phased)
1. Inspect chat history hydration and sync merge paths in `chat_screen.dart` and `chat_history_api_service.dart`.
2. Introduce deterministic chronological sorting for history snapshots (especially initial load) using createdAt/timestamp with stable tie-breakers.
3. Add/extend unit tests in mobile chat app history service tests to validate sorting behavior for unsorted message payloads.
4. Run repository bootstrap and targeted Flutter tests for the modified package.
5. Check code maps and update if behavior/indexing expectations changed.

# Acceptance Criteria
- On history load, messages are ordered by creation time (oldest to newest), with deterministic tie-breakers.
- Mixed default/OpenClaw scenarios with pending and later-delivered messages no longer render in incorrect order.
- `flutter test` for `apps/mobile_chat_app` passes for affected test files.
