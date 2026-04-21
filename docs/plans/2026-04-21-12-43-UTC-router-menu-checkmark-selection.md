# Background
The router switch popup now has silent success behavior, but users still need clear visibility into which router option is currently selected. The menu header currently includes both partition type and selected value, which is redundant once selection is visually indicated.

# Goals
- Show current selection using a checkmark in the popup menu options.
- Reserve left-side checkmark space for every selectable menu item.
- Simplify the menu header line to show only partition type.

# Implementation Plan (phased)
1. Add reusable menu option rendering with fixed leading checkmark slot.
2. Update channel router menu items to render checkmarks based on current selection.
3. Update thread router menu items to render checkmarks based on explicit thread setting (including Follow channel).
4. Simplify non-selectable header row text for channel/thread sections.
5. Run focused Flutter tests for chat navigation UI regressions.

# Acceptance Criteria
- In channel context, the active router option shows a checkmark and other options keep aligned left padding.
- In thread context, exactly one of Follow channel / Bricks Default / OpenClaw shows a checkmark.
- Header line displays only `Channel router` or `Thread router` without selected value text.
- Validation command(s): `./tools/init_dev_env.sh`, `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`.
