# Background
The chat sidebar currently creates channels with auto-generated names, does not support channel rename/archive actions, and the chat app bar title is hardcoded as "Bricks".

# Goals
- Require user-provided channel names during creation.
- Ensure channel names are unique.
- Add long-press channel actions in the sidebar for rename and archive.
- Hide archived channels from the sidebar by removing them from the active channel list.
- Show the active channel name in the top app bar title, left-aligned.

# Implementation Plan (phased)
1. Extend `ChatNavigationPage` to support long-press channel context actions (rename/archive) via callbacks and a popup menu.
2. In `ChatScreen`, replace auto-generated channel creation with a name input dialog and duplicate-name validation.
3. Implement channel rename and archive handlers in `ChatScreen`, including active-channel fallback behavior when archiving.
4. Update app bar title rendering to use the active channel name.
5. Add/adjust widget tests for navigation menu behavior and command dispatch.
6. Run Flutter checks/tests and update code maps if feature/logic entry points changed.

# Acceptance Criteria
- Long-pressing a channel in the drawer shows actions for rename and archive.
- Renaming a channel updates its displayed name and does not allow duplicates.
- Archiving a channel removes it from the visible channel list.
- Creating a channel requires entering a name and cannot create with duplicate names.
- The app bar title displays the active channel name (left aligned).
- Relevant widget tests pass.
