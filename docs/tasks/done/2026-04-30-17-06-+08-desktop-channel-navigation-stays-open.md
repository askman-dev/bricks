# Desktop Channel Navigation Stays Open

## Background

The chat navigation page is reused for both compact mobile drawers and wide desktop inline navigation. Channel taps currently request navigation close before switching channels. That is correct on compact screens, where the drawer covers the conversation, but it is not correct on wide screens where the inline navigation pushes the conversation area to the right and should remain available for repeated channel switching.

## Goals

- Keep compact drawer behavior unchanged: tapping a channel closes the drawer.
- Keep wide inline navigation open when a channel is selected.
- Preserve existing close behavior for explicit navigation close actions such as the back arrow and settings/actions.
- Cover the behavior with focused widget tests.

## Implementation Plan

1. Add an explicit channel-selection close policy to `ChatNavigationPage`.
2. Use the default close-on-channel-select policy for mobile drawer usage.
3. Disable close-on-channel-select for the desktop inline navigation call site.
4. Add widget tests for both default close behavior and desktop-style non-closing channel selection.
5. Update code maps if the navigation behavior index needs to reflect the new wide-screen behavior.

## Acceptance Criteria

- On compact/mobile navigation, tapping a channel closes the drawer and switches the selected channel.
- On wide/desktop inline navigation, tapping a channel switches the selected channel without closing the navigation panel.
- The explicit close control still closes wide/desktop inline navigation.
- Existing channel rename/archive behavior is unchanged.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
