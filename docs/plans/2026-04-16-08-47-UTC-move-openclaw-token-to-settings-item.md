## Background
The PR feedback requests moving the token-generation action out of Model Settings into the top-level Settings page as a dedicated settings item, and renaming the button text to "Openclaw Token".

## Goals
1. Remove token-generation UI from Model Settings.
2. Add a dedicated "Openclaw Token" settings entry in Settings.
3. Keep token generation/copy behavior working with updated naming.

## Implementation Plan (phased)
- [x] Locate existing token generation implementation and related widget tests.
- [x] Move token UI/logic from `ModelSettingsScreen` into a dedicated settings flow.
- [x] Add a new settings list item in `SettingsScreen` that navigates to Openclaw token UI.
- [x] Update and add targeted widget tests for the new location and label.
- [x] Run targeted Flutter tests and finalize.

## Acceptance Criteria
- "Get Xiaolongxia Token" no longer appears in Model Settings.
- Settings page contains a new "Openclaw Token" item.
- Entering that item allows generating a token, viewing token metadata, and copying the token.
- Widget tests cover the new settings entry and token generation/copy flow.
