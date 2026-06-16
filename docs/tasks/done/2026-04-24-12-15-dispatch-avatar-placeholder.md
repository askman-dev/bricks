# Background
The chat UI currently marks the user message as accepted immediately after `/api/chat/respond` returns, which is correct. However, assistant identity only becomes visible once a real assistant message arrives. For async routers and model streaming, that creates a visible gap where the user knows the task was accepted but cannot yet see which assistant has taken over.

# Goals
1. Show assistant identity as soon as backend dispatch begins, before assistant text arrives.
2. Keep the user-message acceptance checkmark driven by `/api/chat/respond`.
3. Reuse the existing SSE message pipeline instead of introducing a separate event channel.
4. Preserve stable ordering between the accepted user message and the dispatch placeholder assistant row.

# Implementation Plan
## Phase 1
Emit a backend-owned assistant dispatch placeholder using the existing `chat_messages` + SSE flow for both OpenClaw and default-router async execution paths.

## Phase 2
Render assistant dispatch placeholders in the mobile chat UI as avatar/header + processing indicator without showing an empty assistant text bubble.

## Phase 3
Add regression tests for backend dispatch placeholder emission, frontend ordering, and placeholder rendering behavior. Update code maps because user-visible chat behavior and test indexes change.

# Acceptance Criteria
1. After `/api/chat/respond` returns, the user message still shows accepted state immediately.
2. Before assistant text is available, SSE can deliver a placeholder assistant row that shows the receiving assistant identity.
3. When the real assistant reply for the same `messageId` arrives, the placeholder becomes a normal assistant message instead of rendering as a separate extra row.
4. Relevant backend and Flutter tests pass.
