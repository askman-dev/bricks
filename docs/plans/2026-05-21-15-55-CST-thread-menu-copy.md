# Thread Menu Copy

## Background

The chat app bar thread dropdown still uses Chinese copy for the main thread and
new child thread action. The product language now uses `Thread` instead of
section/subsection wording.

## Goals

- Change the main thread label from `主区` to `Thread`.
- Change the create child thread menu item from `新建子区` to `New Thread`.
- Change the default channel display name to `Default Channel`.
- Keep thread identity and storage fields unchanged.

## Implementation Plan

1. Update user-facing app bar thread dropdown copy in `chat_screen.dart`.
2. Update default channel display-name copy in `chat_screen.dart` and widget
   tests.
3. Update code maps so smoke checks match the current product wording.
4. Run Dart formatting and targeted Flutter analysis.

## Acceptance Criteria

- The app bar displays `Thread` when the active thread id is `main`.
- The app bar displays the specific thread name when a child thread is active.
- The thread dropdown create action reads `New Thread`.
- The default channel appears as `Default Channel`.

## Validation Commands

- `dart format apps/mobile_chat_app/lib/features/chat/chat_screen.dart`
- `cd apps/mobile_chat_app && flutter analyze`
