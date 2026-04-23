# Background
The chat flow currently treats default-router `/api/chat/respond` as a synchronous request/response path, and the Flutter UI inserts an optimistic empty assistant placeholder immediately after the user sends a message. Delivery/read indicators for user messages are also tied to older heuristics, which no longer match the latest product behavior for default-router and OpenClaw flows.

# Goals
1. Make default-router `respond` follow the async transport contract: persist user message first, return quickly, and complete assistant generation/persistence asynchronously.
2. Remove immediate fake assistant placeholder rendering from the client; assistant content should appear only when actual reply content starts arriving from backend sync/SSE.
3. Update user-message delivery indicators to the latest rule:
   - show a first check mark when the user query is persisted;
   - add a second conversation-status mark when assistant processing/reply starts;
   - when the responder is OpenClaw, the second mark must be 🦞 instead of ✓.
4. Ensure sync/SSE wiring still activates for default-router async replies after send.

# Implementation Plan (phased)
## Phase 1: Backend respond async unification
- Refactor `apps/node_backend/src/routes/chat.ts` `/respond` so both default and OpenClaw return `mode: "async"` after accepted persistence.
- Persist the user message first.
- For default router, schedule background generation + assistant message persistence (accepted/completed/failed state transitions) without blocking HTTP response.
- Add/update route tests to validate default router no longer behaves synchronously.

## Phase 2: Flutter send-flow and SSE behavior
- Update `apps/mobile_chat_app/lib/features/chat/chat_screen.dart` send flow to stop adding optimistic empty assistant messages.
- Keep user message visible, then rely on SSE/sync snapshots for assistant records.
- Ensure active-scope sync activation includes pending user tasks so default-router async replies are still fetched even without a local assistant placeholder.

## Phase 3: Delivery indicator behavior
- Update `apps/mobile_chat_app/lib/features/chat/widgets/message_list.dart` delivery indicator model/UI to support two-stage icons.
- Implement first icon (persisted check) and second icon (reply started, with OpenClaw lobster variant).
- Update widget tests in `apps/mobile_chat_app/test/message_list_test.dart` accordingly.

## Phase 4: Code map and validation
- Run targeted backend + Flutter tests covering changed behavior.
- Review and update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` to reflect behavior changes.

# Acceptance Criteria
- `POST /api/chat/respond` for default scope responds with async accepted payload without waiting for LLM text generation.
- User message record is persisted before async response is returned.
- Flutter chat does not render an empty/fake assistant placeholder on send.
- User message delivery UI shows two-stage state per latest rules (OpenClaw second icon uses lobster).
- Relevant automated tests pass for backend route behavior and Flutter delivery indicator rendering.
