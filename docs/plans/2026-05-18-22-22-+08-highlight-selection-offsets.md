# Highlight Selection Offsets

## Background

PR 255 added highlight creation and deletion through Flutter selection toolbars, but the implementation still identifies highlights by selected text. That is fragile for repeated text, markdown rendering, code blocks, tables, and selections that span multiple rendered blocks. The UI needs to keep the floating toolbar path working while storing enough range information to render a single logical highlight as multiple visual subsegments.

## Goals

- Restore a reliable selection toolbar for assistant message highlights.
- Resolve the selected message before creating or deleting a highlight.
- Prefer stored message offsets over text search when rendering highlights.
- Render a logical highlight across markdown paragraphs, code blocks, and table cells as separate visual subsegments.
- Preserve the existing backend API shape while improving client-side behavior for existing highlight records.

## Implementation Plan

1. Move highlight selection menu handling from the whole message list to per-assistant-message selection scopes so the selected text is associated with a stable message id.
2. Add message-level selected text resolution that maps rendered selection text back to normalized message offsets when possible, falling back to bounded text search for older or ambiguous cases.
3. Update highlight rendering to use `startOffset` and `endOffset` first, splitting each rendered text run by range intersections instead of searching for matching text inside every span.
4. Apply the same range-splitting path to markdown paragraph text, block quotes, code blocks, and table cell text so one highlight can produce multiple visual subsegments.
5. Add focused widget tests for duplicate text, code block/table/cross-paragraph rendering, and callback offsets.
6. Check whether code maps need updates because this changes feature entry paths and highlight logic.

## Acceptance Criteria

- Selecting text in an assistant message shows `划线` in the floating selection toolbar.
- Creating a highlight calls the callback with the selected assistant message id and a non-null range when the selection can be resolved.
- Existing highlights with stored ranges render only at their intended message offsets, even when the same text appears elsewhere.
- A single highlight range can visibly underline multiple rendered pieces when it crosses paragraph, markdown, code, or table boundaries.
- Selecting an existing highlighted range can show `删除划线` and delete the matching highlight without searching other messages first.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
