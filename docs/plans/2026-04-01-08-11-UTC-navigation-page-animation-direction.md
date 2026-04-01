# Background
Users reported that tapping the top-left button on the chat page opens the `Navigation` page with a right-to-left push animation. They want this specific transition to enter from left to right instead.

# Goals
- Make the `Navigation` page transition in from the left edge when opened from chat.
- Keep existing destination behavior and returned action handling unchanged.
- Validate that the app still analyzes cleanly after the route change.

# Implementation Plan (phased)
1. Locate the chat screen route push code that opens `ChatNavigationPage`.
2. Replace the default `MaterialPageRoute` with a custom route transition that slides from `Offset(-1, 0)` to `Offset.zero`.
3. Keep route result typing (`ChatNavigationAction`) intact.
4. Run environment bootstrap and a focused Flutter/Dart check to verify no analyzer regressions.

# Acceptance Criteria
- When the user taps the top-left navigation button on chat, the `Navigation` page visibly enters from left to right.
- Selecting actions on the `Navigation` page still returns the same `ChatNavigationAction` results and behavior.
- `flutter analyze` for the mobile chat app completes without new issues.
