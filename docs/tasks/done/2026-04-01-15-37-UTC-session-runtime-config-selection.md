# Background
Users need session-scoped model/config selection that can differ from default configuration, especially for parallel conversations and temporary model switches.

# Goals
- Add session-level (in-memory) runtime selection for config + model in chat.
- Support one config exposing multiple model options.
- Ensure temporary session selection does not mutate persisted default config.

# Implementation Plan (phased)
1. Extend `LlmConfig` parsing to include available model options from config payload.
2. Add chat runtime state for selected config/model, loaded from default config at startup.
3. Add a chat UI control to switch runtime config/model for the current session only.
4. Rebuild agent sessions when runtime selection changes so subsequent sends use new runtime settings.
5. Run analysis and app tests.

# Acceptance Criteria
- User can choose config and model in chat without editing saved defaults.
- Selection applies to subsequent messages in current session.
- Reloading app continues to use persisted default unless user switches again.
