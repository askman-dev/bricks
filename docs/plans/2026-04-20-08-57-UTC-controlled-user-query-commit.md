# Background
The chat frontend previously persisted messages by repeatedly upserting the whole in-memory message list. During streaming and state transitions this caused replay writes, write sequence churn, and potential ordering side effects.

# Goals
1. Stop full-list client-side persistence on every streaming delta or state transition.
2. Rely on the backend `/respond` endpoint for authoritative user-query persistence (the endpoint already upserts the user message before generating a response).
3. Reduce unnecessary historical message upserts to improve write sequence stability and ordering signal quality.

# Implementation Plan (phased)
1. Remove debounced whole-list persistence (`_persistActiveScopeMessages` / `_doPersistActiveScopeMessages`) from `chat_screen.dart`.
2. Remove the `_persistDebounce` timer and related cleanup.
3. Remove all call sites that trigger whole-list upserts during streaming, message updates, and scope changes.
4. Confirm that the backend `/respond` endpoint already persists the user message (both sync and OpenClaw async paths).
5. Verify that no client-side single-message commit remains — the `/respond` endpoint is the single source of persistence for user queries.
6. Run targeted Dart/Flutter tests and formatting for touched files.
7. Review code-map impact and update maps only if feature/logic/test entry indexing changed.

# Acceptance Criteria
- Streaming assistant updates no longer trigger full-history upsert requests from the client.
- User message persistence is handled exclusively by the backend `/respond` endpoint (one write per send).
- No client-side duplicate upsert of the user message occurs alongside the `/respond` call.
- Existing chat history API service tests pass for updated behavior.
