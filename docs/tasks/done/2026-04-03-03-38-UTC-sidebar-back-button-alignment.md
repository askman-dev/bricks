# Background
The sidebar back button row in the mobile chat app does not align precisely with the parent chat page app bar menu button row. The goal is to make the drawer-open header layout visually and structurally match the parent page header alignment.

# Goals
- Align the sidebar back button hit area and icon placement to the same horizontal/vertical geometry used by the chat app bar leading menu button.
- Align the sidebar header title baseline and spacing with app bar title conventions.
- Keep behavior unchanged (back button still closes the drawer).

# Implementation Plan (phased)
## Phase 1: Inspect and normalize header structure
- Update `ChatNavigationPage` header row to mirror app bar-like dimensions (`kToolbarHeight`) and leading slot width.
- Replace ad-hoc paddings with deterministic spacing that matches Material app bar leading/title layout.

## Phase 2: Style and semantics parity
- Use a back icon style that matches app bar icon sizing and visual weight.
- Apply title text style from `Theme.of(context).textTheme.titleLarge` to align with app bar typography.

## Phase 3: Validate
- Run formatter for modified Dart file.
- Run targeted Flutter widget test(s) for chat navigation UI behavior.

# Acceptance Criteria
- When the drawer is open, the back button row appears aligned to the same top-row geometry as the parent chat app bar menu row.
- Back button remains tappable and closes the drawer.
- Existing chat navigation tests pass after the change.
- Validation commands are executed: `./tools/init_dev_env.sh` and `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`.
