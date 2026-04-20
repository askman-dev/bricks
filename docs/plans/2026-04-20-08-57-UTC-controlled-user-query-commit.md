# Background
The chat frontend currently persists messages by repeatedly upserting the whole in-memory message list. During streaming and state transitions this causes replay writes, write sequence churn, and potential ordering side effects. Failures also silently auto-retry through repeated UI-triggered persistence calls.

# Goals
1. Persist only the current user query as a controlled, single-message commit (`length = 1`) per send action.
2. Block new user-query persistence attempts while one commit is pending/in-flight.
3. Replace implicit repeated retries with explicit user-triggered retry and visible toast/snackbar feedback.
4. Reduce unnecessary historical message upserts to improve write sequence stability and ordering signal quality.

# Implementation Plan (phased)
1. Add controlled user-query persistence state to `chat_screen.dart`:
   - Track in-flight and failed-pending user query commit.
   - Add helpers for pending checks, commit execution, and failure snackbar with retry action.
2. Refactor send flow:
   - Build user message payload once and append locally.
   - Execute exactly one commit attempt for the user message (`upsertMessages` with singleton list).
   - Prevent additional sends when a pending user-query commit exists.
3. Remove whole-list auto persistence triggers from normal message updates/streaming paths.
4. Add/adjust tests in `chat_history_api_service_test.dart` to validate singleton upsert payload behavior.
5. Run targeted Dart/Flutter tests and formatting for touched files.
6. Review code-map impact and update maps only if feature/logic/test entry indexing changed.

# Acceptance Criteria
- A send action results in one user-query persistence attempt with exactly one message in request payload.
- While a user-query commit is pending/in-flight, additional sends are rejected with visible feedback.
- On commit failure, no automatic retry loop occurs; retry requires explicit user action from snackbar/toast.
- Streaming assistant updates no longer trigger full-history upsert requests.
- Existing chat history API service tests pass for updated behavior.
