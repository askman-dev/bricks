# Problem
Add a per-scope message router for Bricks chat so each channel and thread can choose between:
- `default`: messages are handled inside Bricks by `/api/chat/respond` and `generateWithUserConfig(...)`
- `openclaw`: user messages are handed off asynchronously through the Bricks platform/OpenClaw plugin path, and plugin-side updates flow back into Bricks UI

The current codebase does not persist channel/thread settings yet. Chat scopes are inferred from existing traffic, and the mobile UI still assumes `/api/chat/respond` returns assistant text immediately.

# Proposed approach
## 1. Persist scope router settings
- Add a backend persistence model for scope settings, recommended as a new `chat_scope_settings` table keyed by `(user_id, channel_id, thread_id nullable)`.
- Store a `router` enum/string with allowed values `default` and `openclaw`.
- Resolve the effective router as:
  - thread-level override
  - else channel-level setting
  - else implicit `default`
- Extend chat scope APIs so the mobile app can fetch and update both channel-level and thread-level router settings.

## 2. Branch backend dispatch by effective router
- Keep `/api/chat/respond` as the main authenticated entrypoint for app-originated sends.
- For `default`, preserve the existing synchronous flow:
  - accept task
  - persist the user message
  - call `generateWithUserConfig(...)`
  - persist the assistant message
  - return assistant text immediately
- For `openclaw`, change the flow to async handoff:
  - accept task
  - persist the user message
  - skip internal LLM generation
  - return an accepted/pending response shape that the UI can track
  - let the OpenClaw plugin pull the new user message from the platform events API and write back assistant updates through `/api/v1/platform/messages`
  - if the user's plugin/token is not currently active, keep the message pending instead of falling back to `default`

## 3. Tighten the platform event bridge
- Filter platform events so only eligible user-originated messages from `openclaw`-routed scopes are emitted to plugins.
- Prevent replay/echo loops for plugin-authored assistant messages and platform patch updates.
- Preserve conversation resolution through the existing `(channelId, threadId, sessionId)` mapping.

## 4. Update the mobile chat UX
- Add router controls for channels and threads in the chat UI/state managed from `chat_screen.dart`.
- Hydrate scope settings from backend instead of treating channels/threads as traffic-derived only.
- Keep current behavior for `default`.
- For `openclaw`, stop assuming an immediate assistant reply:
  - show dispatched/pending task state
  - rely on existing chat sync/history updates to render plugin-created assistant messages when they arrive
  - keep messages pending while OpenClaw is unavailable rather than silently rerouting them

## 5. Validate end to end
- Backend tests for router resolution, new scope settings APIs, `/api/chat/respond` branching, and platform event filtering.
- Flutter tests for effective-router resolution and async/pending message UX.
- Plugin tests for event handling assumptions if server-side filtering changes.
- Run the existing package build/test commands for touched apps.

# Todos
1. Add router persistence and scope settings APIs in the backend.
2. Branch `/api/chat/respond` into synchronous `default` handling and asynchronous `openclaw` handoff.
3. Filter platform events and writeback behavior so only OpenClaw-routed user messages are exported and plugin updates do not loop.
4. Add channel/thread router controls and async OpenClaw task handling in the Flutter chat UI.
5. Add/update tests and run repository checks for the touched packages.

# Notes
- Current scope discovery is traffic-derived via `/api/chat/scopes`; there is no persisted channel/thread settings model yet.
- `ChatHistoryApiService.respond()` and `chat_screen.dart` currently expect immediate assistant text, so OpenClaw requires a contract/UI change rather than a pure config switch.
- Recommended precedence: thread router overrides channel router.
- Confirmed behavior: if a scope is set to `openclaw` and the local plugin/token is not currently available, Bricks should still accept the message and leave it pending until OpenClaw becomes available. There should be no silent fallback to `default`.
