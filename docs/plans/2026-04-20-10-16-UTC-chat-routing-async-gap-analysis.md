# Background
The user asked whether the two routing modes (`default` and `openclaw`) are synchronous or asynchronous in the current implementation, and whether the implementation matches an expected architecture where: (1) user messages are durably saved first, (2) AI routing/generation runs after persistence, (3) assistant output is streamed to the user, and (4) AI failures still preserve user messages so retries remain possible.

# Goals
1. Verify the current backend behavior for `default` vs `openclaw` routing.
2. Verify the current frontend behavior for response rendering (streaming vs non-streaming).
3. Identify concrete gaps between current behavior and the requested async-first flow.
4. Record findings with file-level evidence for follow-up implementation work.

# Implementation Plan (phased)
## Phase 1: Trace backend request path
- Inspect `apps/node_backend/src/routes/chat.ts` for `/api/chat/respond` routing behavior.
- Confirm persistence ordering for user and assistant messages.
- Confirm error-path semantics when LLM invocation fails.

## Phase 2: Trace frontend response consumption
- Inspect `apps/mobile_chat_app/lib/features/chat/chat_history_api_service.dart` to determine whether `/respond` is treated as sync/async and whether SSE/stream endpoints are used.
- Inspect `apps/mobile_chat_app/lib/features/chat/chat_screen.dart` to verify UI update behavior for `isAsync` responses and polling.

## Phase 3: Gap analysis
- Compare observed behavior with requested behavior:
  - both routes async
  - persist user message before AI call
  - stream assistant tokens
  - preserve retryability when AI fails
- Summarize mismatches and partial matches.

# Acceptance Criteria
- The analysis explicitly states which route is sync vs async today, with evidence from backend route logic.
- The analysis explicitly states whether assistant output is token-streamed in the chat path today.
- The analysis explicitly states whether user messages are persisted before AI call and what happens on AI failure.
- Findings are documented in a committed plan artifact under `docs/plans/`.
