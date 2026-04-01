# Background
The chat composer currently shows a placeholder voice button and does not provide a direct in-chat model switcher. Users also reported that sending a message can appear to stall with no visible model request/response behavior.

# Goals
1. Ensure message sending always uses a resolved default model when no explicit agent model is chosen.
2. Replace the voice button in the composer with a plus button that opens model selection.
3. Populate the model selection list from configured LLM configs and make selection apply to the current session and persisted default model.
4. Keep behavior aligned with existing settings persistence semantics.

# Implementation Plan (phased)
## Phase 1: Model resolution and session behavior
- Introduce chat-level state for current model and configured model options.
- Load default model from `LlmConfigService.fetchDefault()` at startup and on settings return.
- Update session creation keying so sessions are keyed by agent and model to avoid stale session settings.
- Ensure `_settingsForAgent` prefers active in-chat selected model and falls back to configured default.

## Phase 2: Composer UI and interaction
- Replace microphone icon button with a plus icon button.
- Add callback plumbing from `ComposerBar` to `ChatScreen` for opening model selection.
- Show a popup menu from the plus button with all configured model IDs.
- On selection, update in-memory active model for current chat and persist the same model as default via `LlmConfigService.save` on the currently default config.

## Phase 3: Tests and regressions
- Add/update widget tests for `ComposerBar` plus button behavior and callback execution.
- Add/update chat screen tests for model selection fallback and persistence trigger behavior where feasible.
- Run repository bootstrap then targeted Flutter tests and static checks.

# Acceptance Criteria
- Sending a message without explicit per-agent model selection uses a valid default model and starts a request flow.
- The composer left icon is `+` (add) instead of voice/microphone.
- Tapping `+` presents all configured model IDs.
- Selecting a model applies immediately to current chat messages and updates default model persistence consistently with settings default model behavior.
- Existing chat composer send/stop behavior remains functional.
