# Background
The user requested two dark-mode chat UI adjustments in the mobile chat app: (1) make user message bubbles use a clear white-like color similar to a competitor screenshot, and (2) increase spacing between user and assistant messages. The user also asked why the current color feels visually "weak"/"hazy".

# Goals
1. Increase visual clarity of user bubbles in dark mode by using a higher-luminance bubble background and preserving text contrast.
2. Increase perceived separation between user turns and assistant turns in the message list.
3. Keep behavior stable and cover the style adjustments with widget tests where practical.

# Implementation Plan (phased)
## Phase 1: Inspect current tokens and message layout
- Locate chat color tokens and message-list spacing logic in `packages/design_system` and `apps/mobile_chat_app`.

## Phase 2: Apply visual updates
- Update dark-mode user bubble token(s) to a light surface with strong text contrast.
- Adjust message list spacing rules to increase the gap after user bubbles.
- Tune user bubble metadata color so it remains legible on the lighter bubble.

## Phase 3: Validate
- Run environment bootstrap: `./tools/init_dev_env.sh`.
- Run targeted widget tests from mobile package directory, focusing on `message_list_test.dart`.
- If needed, update/add tests that assert bubble color and spacing behavior.

# Acceptance Criteria
- In dark theme, user bubbles render with a light, high-contrast background and readable dark text.
- The vertical gap between a user message block and following assistant content is visibly larger than before.
- Widget tests covering the modified message-list behavior pass (`cd apps/mobile_chat_app && flutter test test/message_list_test.dart`).
