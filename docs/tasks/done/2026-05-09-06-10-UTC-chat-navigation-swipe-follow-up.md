# Background
The initial drawer swipe update disabled `TabBarView` paging and added swipe-to-close behavior, but review feedback identified two follow-ups: the close direction should respect RTL layouts, and the non-tab-switch test should avoid accidentally proving the drawer-close path instead.

# Goals
- Make swipe-to-close respect `Directionality`.
- Keep the “no tab switch on swipe” test focused on tab behavior without triggering close.
- Preserve existing drawer close behavior for LTR navigation.

# Implementation Plan (phased)
1. Update `ChatNavigationPage` drag-end handling to choose the close swipe direction from the current text direction.
2. Refine widget tests to use a non-fling drag for the tab-stability case and assert no close request occurs.
3. Add RTL widget coverage for swipe-to-close.

# Acceptance Criteria
- In LTR, a right-to-left fling closes navigation.
- In RTL, a left-to-right fling closes navigation.
- A horizontal drag no longer changes tabs and does not request close.

# Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
