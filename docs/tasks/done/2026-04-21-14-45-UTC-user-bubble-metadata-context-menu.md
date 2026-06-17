# Background
The user wants to simplify the message row by removing the metadata line outside user bubbles while preserving all existing metadata information. They also want user-bubble metadata to use delivery checkmarks rather than `task:accepted` text, remove visible task/message IDs from the bubble body, and add a long-press context menu with copy/branch/resend actions plus subtle ID diagnostics in the menu footer.

# Goals
1. Keep all user-message metadata but move it into the user bubble.
2. Remove visible `id:task-...` text from message rendering.
3. Replace textual accepted-state indication with the existing first ✓ delivery indicator.
4. Place the second delivery indicator immediately after the first inside bubble metadata.
5. Add long-press context menu on user bubbles with:
   - Copy (implemented)
   - Branch (placeholder)
   - Resend (placeholder)
   - Bottom two-line light metadata: message id and task id.
6. Keep/extend tests to cover the updated rendering and menu behavior.

# Implementation Plan (phased)
## Phase 1: Bubble metadata layout
- Update `message_list.dart` to render user metadata row inside the user bubble.
- Remove the external metadata row for user messages.
- Keep assistant rows unchanged.

## Phase 2: Metadata semantics cleanup
- Stop rendering `task:*` and `id:*` text in the user bubble body.
- Keep timestamp/thread/recovered text and delivery icons together inside bubble metadata.

## Phase 3: Long-press context menu
- Add a long-press handler for user bubbles.
- Implement context menu actions and footer metadata lines.
- Implement copy action with clipboard support.

## Phase 4: Validation and map synchronization
- Run mobile app tests for `message_list_test.dart`.
- Update code maps to include the new long-press/context-menu behavior in chat session smoke checks/keywords.

# Acceptance Criteria
- User message rows no longer show metadata text outside the bubble.
- User bubble contains timestamp/thread metadata and delivery checks.
- `task:accepted` / `id:task-*` are not shown in user bubble text.
- Long-pressing a user bubble shows a menu with Copy/Branch/Resend and footer metadata lines for message/task IDs.
- `flutter test` for message list passes from `apps/mobile_chat_app`.
