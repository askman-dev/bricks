# Background
The chat composer currently renders a horizontal divider line between the text input area and the button row, and the send button uses a larger filled style than the left-side action button. This creates an imbalanced visual hierarchy in the input area.

# Goals
- Remove the divider above the button row in the composer.
- Make the send button visual size match the left action button.
- Preserve existing send/loading/disabled behavior.

# Implementation Plan (phased)
1. Inspect `ComposerBar` widget layout and identify the divider and send button implementations.
2. Remove the divider widget between text field and action row.
3. Replace the oversized filled send icon button with a standard `IconButton` so it matches the action button's visual scale.
4. Keep spinner behavior for sending state and keep stop button behavior unchanged.
5. Run focused Flutter tests for the mobile app package.

# Acceptance Criteria
- In the composer UI, there is no visible dividing line above the action row.
- The send button appears the same size class as the left action icon button.
- Message send action still triggers on send button tap and Enter/send submit.
- Validation command succeeds: `cd apps/mobile_chat_app && flutter test`.
