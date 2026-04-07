# Background
The chat navigation drawer currently places the channel creation action in the top toolbar as an icon-only control. The requested UX is to move this action into the "频道" group header so the action is contextually grouped with channel management and rendered as an icon+text button.

# Goals
- Move the "新建频道" action from the top-right navigation header into the "频道" section header row.
- Render the relocated action with an icon and text label.
- Keep existing action wiring (`ChatNavigationAction.createChannel`) intact.
- Update widget tests to validate the new location/presentation.

# Implementation Plan (phased)
1. Update `ChatNavigationPage` layout:
   - Remove the top app bar `IconButton` for new-channel.
   - Replace the simple "频道" header text with a row containing the section title and a trailing icon+text button.
   - Keep spacing and visual hierarchy appropriate for drawer content.
2. Update tests in `chat_navigation_page_test.dart`:
   - Replace tooltip assertion for old icon button with assertions for the new text/icon button.
   - Ensure expectations still cover the section title and static navigation elements.
3. Run targeted Flutter widget tests for the affected file.

# Acceptance Criteria
- In the navigation drawer, "新建频道" appears on the same line as the "频道" group title, aligned to the right.
- The "新建频道" control uses icon+text presentation instead of icon-only presentation.
- Tapping "新建频道" still emits `ChatNavigationAction.createChannel`.
- Updated widget tests pass via `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`.
