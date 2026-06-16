# Background
The current chat navigation uses a narrow slide-in Drawer. The requested behavior is a page-level navigation experience so users can focus on navigation options in a full page, while still being able to return to the chat screen with a back action.

# Goals
- Replace the narrow Drawer interaction with a full-page navigation screen.
- Keep existing navigation actions (manage agents, session settings, app settings).
- Ensure users can return to the chat conversation via a back button.

# Implementation Plan (phased)
## Phase 1: Build a dedicated navigation page
- Add a new screen under the chat feature that renders navigation options in a full-page Scaffold.
- Provide a standard AppBar back button for returning to chat.
- Return a typed action result from the page when users pick an actionable menu item.

## Phase 2: Integrate with chat screen
- Remove Drawer usage from `ChatScreen`.
- Add an AppBar menu button that pushes the new navigation page.
- Handle returned actions in `ChatScreen` and route to existing destination screens.

## Phase 3: Validate behavior
- Run Flutter workspace bootstrap script.
- Run targeted static analysis/tests for the mobile chat app to confirm no regressions.

# Acceptance Criteria
- Tapping the chat AppBar menu opens a full-page navigation screen instead of a narrow drawer.
- The navigation page has a back button that returns to the chat conversation.
- Selecting Manage Agents, Session Settings, and Settings still opens the same destination screens.
- `flutter analyze` for the mobile chat app succeeds after the change.
