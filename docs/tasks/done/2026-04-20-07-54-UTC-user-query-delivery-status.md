# Background
Users need clearer visual delivery states on user query bubbles when chat routing can be synchronous (default LLM route) or asynchronous remote routes (OpenClaw and future routers).

# Goals
- Show no delivery mark for default-route user messages.
- Show OpenClaw-specific status progression on user bubbles: pending/accepted and pulled states as gray lobster, then green check after reply.
- Show generic remote-route status progression on user bubbles: gray check after persistence, green check after reply.
- Keep status logic robust when state updates arrive later through sync/history refresh.

# Implementation Plan (phased)
1. Extend chat message metadata parsing/storage in mobile app to preserve server `source` metadata and router info from `/api/chat/respond`.
2. Update send flow to propagate router-derived source metadata back onto the local user message after respond acknowledgement.
3. Add delivery-indicator derivation in `MessageList` for user messages based on route type and assistant reply state within the same task.
4. Render visual indicators beside user message timestamps using lobster/check icons and route-specific color rules.
5. Add widget tests to cover default route, OpenClaw pending/completed, and generic remote pending/completed behavior.
6. Sync code maps for chat-session regression coverage updates.

# Acceptance Criteria
- For default route (`backend.respond`), user bubbles show no delivery status icon.
- For OpenClaw route (`backend.respond.openclaw`), user bubbles show gray lobster before completion and green check after assistant reply completion.
- For other remote routes (`backend.respond.<router>`), user bubbles show gray check before completion and green check after assistant reply completion.
- `flutter test test/message_list_test.dart` passes from `apps/mobile_chat_app`.
