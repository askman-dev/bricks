# Chat Navigation Drawer-Only Cleanup

## Background
`ChatNavigationPage` historically supported both drawer usage and standalone route usage. Current product interaction is drawer-based from `ChatScreen`, and dual-mode fallback logic introduces ambiguity and legacy behavior.

## Goals
- Confirm and align `ChatNavigationPage` with current drawer-only interaction.
- Remove standalone-route fallback behavior from navigation page actions.
- Keep current UX behavior unchanged for users in the drawer flow.

## Implementation Plan (phased)
1. Update `ChatNavigationPage` to require an action callback and remove `Navigator.pop` fallback behavior.
2. Change back-button close logic to drawer-only close behavior (no route-pop fallback).
3. Update widget tests to validate drawer-centric behavior and remove obsolete standalone route tests.
4. Run targeted Flutter tests for the navigation page.

## Acceptance Criteria
- `ChatNavigationPage` no longer contains standalone-route fallback logic.
- Back button closes the open drawer.
- Action taps still emit expected callbacks.
- `flutter test test/chat_navigation_page_test.dart` passes.
