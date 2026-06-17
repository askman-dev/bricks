# Background
The chat page currently shows a router switch popup button in the top-right AppBar area. The requested UX is to place the router switch control near the composer controls at the lower-left side, immediately to the left of the existing tune/config button, and to show route-specific icons (including a lobster icon for openclaw).

# Goals
- Move the router switch button from AppBar actions to the composer action row.
- Place the router button to the left of the existing config/tune button.
- Make the router button icon reflect the currently effective router:
  - default route: suitable default routing icon
  - openclaw route: lobster icon (🦞)
- Keep button sizing/layout stable regardless of icon type.

# Implementation Plan (phased)
1. Extend `ComposerBar` API to accept an optional router menu button widget that can be rendered before the config button.
2. In `ChatScreen`, remove the existing AppBar router popup button.
3. In `ChatScreen`, build the router popup button and pass it into `ComposerBar` through the new slot.
4. Implement dynamic icon rendering for router button based on `_effectiveRouterForScope()`, using a fixed-size container so emoji/icon changes do not alter layout.
5. Run formatting and targeted Flutter tests.

# Acceptance Criteria
- Router popup button no longer appears in top-right AppBar.
- Router popup button appears in composer controls, immediately left of the config/tune button.
- Effective router icon changes with route state (default uses routing icon, openclaw shows 🦞).
- Switching icon does not change button size or row layout.
- Validation commands pass (at minimum: `dart format` on modified files and relevant Flutter test command).
