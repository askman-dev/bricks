# Sidebar Resize and Composer Focus

## Background

The desktop navigation sidebar has an existing resize handle, but the active hit area is too small and can fail to receive drag gestures reliably. The chat composer also used to keep focus after sending a query, but the current streaming state disables the text field and can drop keyboard focus.

## Goals

- Make the desktop navigation sidebar width adjustable again through the divider handle.
- Keep the composer text field enabled and focused after sending a query.
- Add focused regression coverage for composer focus behavior.

## Implementation Plan

1. Widen the desktop sidebar resize handle hit target and make its gesture behavior opaque.
2. Keep the composer text field enabled during streaming so focus is not dropped.
3. Request composer focus again after submit on the next frame.
4. Update widget tests for streaming-enabled input and post-send focus retention.

## Acceptance Criteria

- Dragging the desktop navigation divider changes the sidebar width within the existing min/max bounds.
- Sending a query clears the draft while the composer text field keeps focus.
- The composer remains focusable while a response is streaming.

## Validation Commands

- `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
