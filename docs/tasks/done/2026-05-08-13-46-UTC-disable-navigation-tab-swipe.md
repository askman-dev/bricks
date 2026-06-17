# Background
The chat navigation panel currently contains two tabs (Channels and Nodes). A horizontal swipe inside the panel switches tabs by default via `TabBarView`, which conflicts with the desired UX for drawer-like navigation.

# Goals
- Prevent horizontal swipe from switching tabs inside chat navigation.
- Make a right-to-left swipe in the navigation trigger close behavior.
- Preserve existing tab switching via tab taps.
- Add/adjust tests for the new gesture behavior.

# Implementation Plan (phased)
1. Update `ChatNavigationPage` gesture handling:
   - Disable tab paging gestures in `TabBarView`.
   - Add a horizontal drag-end handler that closes navigation on right-to-left swipe.
2. Add widget tests:
   - Verify horizontal swipe no longer switches tabs.
   - Verify right-to-left swipe requests close.
3. Run targeted Flutter tests for `chat_navigation_page_test.dart`.

# Acceptance Criteria
- Swiping horizontally inside navigation no longer changes active tab.
- Right-to-left swipe on navigation triggers close callback.
- Existing interactions (tab taps, back button, channel tap logic) continue to work.

# Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
