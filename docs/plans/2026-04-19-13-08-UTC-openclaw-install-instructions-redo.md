## Background

The Openclaw Token settings page currently supports generating and copying only the token value.  
For OpenClaw plugin onboarding, users also need a complete instruction payload that includes plugin parameters and an `openclaw.json` channel snippet.

## Goals

1. Show install instructions right after token generation.
2. Include `pluginId`, `url`, `scopes`, and `token` in a copyable text payload.
3. Add a one-click copy button for the full install instructions.
4. Keep the existing token copy flow unchanged.

## Implementation Plan (phased)

### Phase 1: UI content

- Add a formatter method that builds a full install instruction string from `PlatformTokenBundle`.
- Render an "Install Instructions" section with:
  - concise guidance text,
  - a JSON snippet for `channels` in `openclaw.json`,
  - parameter lines for `pluginId/url/scopes/token`.

### Phase 2: Copy action

- Add `Copy Install Instructions` button.
- Reuse existing clipboard/snackbar helper for consistency.

### Phase 3: Validation and docs index sync

- Update widget tests to verify instruction rendering and copy behavior.
- Update code maps for `openclaw_token_settings` smoke checks and risk notes.

## Acceptance Criteria

1. After generating token info, install instructions are visible on the page.
2. `Copy Install Instructions` copies the full instruction text and shows success feedback.
3. `Copy Openclaw Token` still copies only the token and continues to pass tests.
