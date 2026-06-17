# Background
The current mobile chat composer renders the text input and the tool row (menu + send/stop controls) in separate visual blocks. Product feedback requests a Gemini-like treatment where both regions sit inside one shared rounded border while preserving all current behaviors.

# Goals
- Keep all existing composer functionality unchanged (menu actions, send/stop logic, mention behavior).
- Update only visual/layout styling so the input and tool row appear inside one unified container border.
- Ensure widget tests continue to pass after layout refactoring.

# Implementation Plan (phased)
1. Inspect `ComposerBar` structure and identify where the input and tool row are currently split.
2. Refactor `ComposerBar` layout so input + controls are wrapped by a single bordered `Container` with rounded corners.
3. Remove duplicate inner text-field outline styling, replacing it with a borderless field that sits inside the shared container.
4. Run mobile app tests focused on `composer_bar_test.dart` to validate no functional regressions.

# Acceptance Criteria
- The composer input and bottom tool row render within one rounded rectangular border in the mobile chat UI.
- Menu, send, stop, and mention features behave exactly as before.
- `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart` passes.
