# Background
Feedback from validation indicates no observable `/api/chat/messages/batch` call in the real send path, while `/api/chat/respond` is consistently observed. The previous refactor introduced extra client-side controlled commit logic that may be redundant versus backend-owned persistence in `respond`.

# Goals
1. Remove redundant client-side user-query batch commit logic from the send path.
2. Keep send semantics simple and observable: one send action -> one backend `respond` orchestration request.
3. Avoid introducing hidden persistence side effects or UX gates that are not verifiable in production testing.

# Implementation Plan (phased)
1. Remove `_userQueryCommitInFlight`, `_pendingUserQueryCommit`, and related helper methods from `chat_screen.dart`.
2. Remove `_sendMessage` guards and async calls tied to `_commitUserQuery`.
3. Preserve existing backend-driven `respond` flow and error handling.
4. Run formatting, targeted tests, and analyzer checks.
5. Update code maps only if behavior/index descriptions need alignment.

# Acceptance Criteria
- Sending a message only triggers `/api/chat/respond` from `ChatScreen` send path.
- No code path in `ChatScreen` send flow invokes `upsertMessages`.
- Chat send UI behavior remains functional without new blocking states.
