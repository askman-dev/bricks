# Sidebar Close on Back Button

## Background
In the chat screen drawer navigation, tapping the top-left back arrow currently plays the tap animation but does not close the sidebar in drawer usage.

## Goals
- Ensure tapping the back arrow closes the open drawer when `ChatNavigationPage` is rendered inside a `Scaffold.drawer`.
- Add widget test coverage for drawer-close behavior.

> **Note:** An initial approach considered preserving a `Navigator.maybePop` fallback for standalone (non-drawer) usage. After further review this was superseded by the drawer-only cleanup plan (`2026-04-02-13-30-UTC-chat-navigation-drawer-only-cleanup.md`), which removes standalone-route fallback entirely. The implementation reflects the drawer-only direction.

## Implementation Plan
1. Update `ChatNavigationPage._closeNavigation` to close the drawer via `ScaffoldState.closeDrawer()` (no route-pop fallback).
2. Make `onActionSelected` a required callback; remove `Navigator.pop` fallback for action taps.
3. Add/adjust widget tests in `chat_navigation_page_test.dart` to verify drawer closes after tapping the back arrow and remove obsolete standalone-route tests.
4. Run bootstrap and targeted Flutter tests.

## Acceptance Criteria
- When the sidebar is open from `Scaffold.drawer`, tapping the back arrow closes the drawer.
- `ChatNavigationPage` no longer contains standalone-route fallback logic.
- `flutter test` for `chat_navigation_page_test.dart` passes.
