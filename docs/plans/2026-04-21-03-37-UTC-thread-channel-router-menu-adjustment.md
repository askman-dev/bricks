# Thread/Channel Router Menu Adjustment

## Background
The chat input router menu currently renders both channel-level and thread-level option groups together, which can be confusing when the current conversation scope is channel-only or thread-scoped.

## Goals
1. For thread conversations, keep the thread router choices focused and visible as exactly: Follow channel, Bricks Default, and OpenClaw.
2. For channel conversations, hide the thread router group entirely.
3. Preserve existing router selection behavior and snackbar feedback.

## Implementation Plan (phased)
1. Inspect `chat_screen.dart` router-menu rendering to identify where channel and thread sections are always shown.
2. Update menu-building logic to conditionally include the thread section only when viewing a thread conversation.
3. Verify labels and menu values remain unchanged for thread context (Follow channel + concrete routers).
4. Run targeted Flutter tests for chat UI behavior.

## Acceptance Criteria
1. In channel conversations, the router menu only shows channel router options and no thread router group.
2. In thread conversations, the thread router group appears with exactly three options: Follow channel, Bricks Default, and OpenClaw.
3. Existing compile/test checks continue to pass for the mobile chat app.
