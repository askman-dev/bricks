## Background

The Openclaw Token settings screen currently lets users generate a platform token and copy only the token value.  
For OpenClaw plugin onboarding, users also need structured installation instructions that include `pluginId`, URL, scopes, and token in a shareable format.

## Goals

1. Show a concise installation instruction block immediately after token generation.
2. Include the required parameters (`pluginId`, URL, scopes, token) in the displayed instructions.
3. Provide a one-click copy action for the full instruction text.
4. Keep the existing token-copy flow unchanged.

## Implementation Plan (phased)

### Phase 1: UI and formatting

- Extend `OpenclawTokenSettingsScreen` to build a text instruction template from the generated bundle.
- Render:
  - a short helper text,
  - a JSON example for `openclaw.json` channel config shape,
  - explicit parameter lines (`pluginId`, URL, scopes, token),
  - a `Copy Install Instructions` button.

### Phase 2: Validation

- Update widget tests for `openclaw_token_settings_screen` to verify:
  - installation instructions are rendered after token generation,
  - the new copy button copies the full instruction text,
  - existing token copy behavior still works.

### Phase 3: Code map sync

- Update code maps for the `openclaw_token_settings` feature to reflect the newly added install-instruction copy flow.

## Acceptance Criteria

1. After generating token data, users can see install instructions containing `pluginId`, URL, scopes, and token.
2. Tapping `Copy Install Instructions` copies the entire instruction text and shows success feedback.
3. Tapping `Copy Openclaw Token` still copies only the token and shows existing success feedback.
4. `flutter test` for the related settings screen passes.
