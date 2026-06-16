# Background
The chat left sidebar currently shows a plain "Navigation" label at the top. Users expect a back-style control (left arrow) on the left side of this header so they can explicitly close the sidebar panel.

# Goals
- Add a visible back/close affordance to the left of the "Navigation" title.
- Ensure tapping the control closes the sidebar reliably.
- Keep existing navigation actions and static tiles unchanged.

# Implementation Plan (phased)
1. Update `ChatNavigationPage` header layout from a single text widget to a row containing:
   - a left-arrow `IconButton` for closing,
   - the existing "Navigation" title text.
2. Implement a small internal close handler that calls `Navigator.maybePop(context)` so the panel can dismiss without requiring callback wiring.
3. Extend widget tests to verify the back button is rendered and that tapping it pops the route when the page is pushed.

# Acceptance Criteria
- A left-arrow back button is visible at the top-left of the sidebar, immediately before "Navigation".
- Tapping the back button closes the sidebar/page.
- Existing taps on "Manage Agents" and "Settings" still behave as before.
- Validation command succeeds: `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`.
