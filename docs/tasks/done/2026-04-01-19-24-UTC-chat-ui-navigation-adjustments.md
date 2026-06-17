# Background
The chat UI currently has a microphone button in the composer row, session settings in the sidebar navigation, and model selection in the app bar. On mobile, swiping in from the left edge can also invoke browser back navigation instead of opening in-app navigation.

# Goals
1. Remove the voice/microphone button from the composer input row.
2. Add a secondary action row under the input:
   - Left: an adjustment button that opens a menu containing:
     - 新上下文 (no-op)
     - 模型 (opens the existing model selection dialog)
     - Agents (no-op)
   - Right: send/stop button.
3. Remove "Session Settings" from the sidebar navigation and remove the corresponding page entrypoint from chat navigation flow.
4. Improve left-edge interaction so opening in-app sidebar is preferred and browser-style back navigation is suppressed from the chat root route.

# Implementation Plan (phased)
1. Update `ComposerBar` to remove the mic button, add a new action row/menu, and move send/stop button to the new row.
2. Wire a new callback from `ChatScreen` into `ComposerBar` to launch the existing runtime model configuration dialog.
3. Replace push-based navigation page with a `Drawer`-based sidebar in `ChatScreen` (opened by AppBar menu button and edge drag), and add `PopScope(canPop: false)` at the chat root to suppress back pop on this screen.
4. Simplify `ChatNavigationPage` action enum and menu list by removing session settings.
5. Remove `SessionSettingsPage` source and its dedicated widget test now that it is no longer reachable from the app navigation.

# Acceptance Criteria
1. Composer input no longer shows a mic icon; a separate action row appears below input with adjustment-menu left and send/stop right.
2. Tapping adjustment -> 模型 opens the existing session model dialog.
3. Sidebar no longer contains "Session Settings".
4. Chat root route does not pop on back gesture/action (preventing unintended browser-back behavior from app route pop).
5. Flutter widget tests pass for touched chat/navigation components (`flutter test` in `apps/mobile_chat_app`).
