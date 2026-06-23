# Desktop Sidebar Divider Visibility

## Background

The desktop chat navigation sidebar already has a 12px resize drag handle, but
the visible 1px divider inside that handle does not receive an explicit height.
As a result, the boundary between navigation and chat can be visually missing
even though drag resizing works.

## Goals

- Keep the existing desktop sidebar resize behavior.
- Make the navigation/chat boundary visible whenever the desktop sidebar is
  open.
- Avoid introducing new color tokens or hard-coded colors.

## Implementation Plan

1. Update the desktop sidebar resize handle in `ChatScreen`.
2. Preserve the 12px opaque drag target and resize cursor.
3. Make the inner 1px divider fill the available height using the existing
   theme divider color.
4. Run focused formatting and Flutter analysis.

## Acceptance Criteria

- On desktop, opening the navigation sidebar shows a full-height divider between
  navigation and chat.
- Dragging the divider still changes sidebar width within existing bounds.
- The change does not alter mobile drawer behavior.

## Validation Commands

- `dart format apps/mobile_chat_app/lib/features/chat/chat_screen.dart`
- `cd apps/mobile_chat_app && flutter analyze`
