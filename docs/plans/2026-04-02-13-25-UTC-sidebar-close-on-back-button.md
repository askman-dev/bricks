# Sidebar Close on Back Button

## Background
In the chat screen drawer navigation, tapping the top-left back arrow currently plays the tap animation but does not close the sidebar in drawer usage.

## Goals
- Ensure tapping the back arrow closes the open drawer when `ChatNavigationPage` is rendered inside a `Scaffold.drawer`.
- Preserve existing behavior where the same back arrow pops the route when the widget is used as a standalone page.
- Add widget test coverage for drawer-close behavior.

## Implementation Plan (phased)
1. Update `ChatNavigationPage._closeNavigation` to prefer closing an open drawer via `ScaffoldState.closeDrawer()`.
2. Keep `Navigator.maybePop` fallback for non-drawer contexts.
3. Add/adjust widget tests in `chat_navigation_page_test.dart` to verify drawer closes after tapping the back arrow.
4. Run bootstrap and targeted Flutter tests.

## Acceptance Criteria
- When the sidebar is open from `Scaffold.drawer`, tapping the back arrow closes the drawer.
- Existing route-pop behavior remains valid outside drawer context.
- `flutter test` for `chat_navigation_page_test.dart` passes.
