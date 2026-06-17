# Background
The chat UI needs a dedicated “jump to latest message” control above the composer so users can quickly return to the newest content after scrolling upward.

# Goals
- Add a visible, tappable control that appears when the user is away from the bottom of the message list.
- Scroll directly to the latest message area when the control is tapped.
- Cover behavior with widget tests.

# Implementation Plan (phased)
1. **Message list behavior**
   - Add scroll position tracking in `MessageList`.
   - Compute whether the list is far enough from the bottom to show the jump button.
   - Add a button overlay near the lower center of the message list.
2. **Interaction**
   - Implement animated scroll-to-bottom behavior when the button is tapped.
   - Ensure visibility state updates after auto-scroll and manual scroll.
3. **Validation**
   - Add widget tests for button visibility and tap-to-jump behavior.
   - Run `./tools/init_dev_env.sh` and `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`.

# Acceptance Criteria
- When the user scrolls up away from the bottom, a downward-arrow jump button appears above the composer area.
- Tapping the button scrolls to the latest message.
- The button hides again when the user is near the bottom.
- `flutter test test/message_list_test.dart` passes in `apps/mobile_chat_app`.
