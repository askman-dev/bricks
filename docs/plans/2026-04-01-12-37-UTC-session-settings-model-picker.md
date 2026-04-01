# Background
The previous implementation added model selection inside the chat composer. Product direction has changed: model selection should live in Session Settings, and Session Settings access should be promoted to a top-right chat action instead of sidebar navigation.

# Goals
1. Move model selection UI from composer/chat input area into Session Settings.
2. Add a dedicated Session Settings button in Chat page top-right app bar actions.
3. Remove Session Settings entry from the sidebar navigation page.
4. Keep model selection behavior: apply to current session and persist as default model.

# Implementation Plan (phased)
## Phase 1: Chat layout and navigation
- Remove composer model-picker callback wiring and related UI trigger.
- Add AppBar action button in `ChatScreen` to open Session Settings directly.
- Remove `sessionSettings` option from `ChatNavigationPage` enum and tile.

## Phase 2: Session Settings model section
- Extend `SessionSettingsPage` to accept current model and callbacks.
- Load configured models from `LlmConfigService` and render selectable options in Session Settings.
- On selection, notify chat screen to update in-memory current model and persist default model through existing save flow.

## Phase 3: Validation and tests
- Update/replace widget tests to cover new Session Settings model picker section.
- Run bootstrap + targeted Flutter tests and analyzer checks.

# Acceptance Criteria
- Chat page has a top-right Session Settings icon/button that opens Session Settings.
- Sidebar navigation no longer contains Session Settings entry.
- Session Settings page displays configured model options.
- Selecting a model in Session Settings updates current chat model and persists default model.
- Message sending continues working with the selected/default model.
