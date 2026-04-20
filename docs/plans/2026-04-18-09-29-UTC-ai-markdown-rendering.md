# Background
Users want AI output messages to support markdown-style formatting, with two strict presentation constraints: heading markers (`#`, `##`, etc.) should not increase font size, and heading blocks should not introduce extra top/bottom spacing compared with normal text. The chat message list currently renders assistant messages as plain `Text`, so markdown semantics are not visualized.

# Goals
1. Render assistant message content with lightweight markdown formatting for headings, inline emphasis, and list indentation.
2. Keep heading typography aligned to body text size while using bold weight only.
3. Avoid extra block margin/padding for heading lines so visual rhythm matches plain paragraphs.
4. Preserve existing user-message rendering and behavior.
5. Add tests covering heading style normalization and list indentation output.

# Implementation Plan (phased)
## Phase 1: Introduce a lightweight markdown renderer for assistant messages
- Add a `_AssistantMarkdownText` widget in `message_list.dart`.
- Parse assistant text line-by-line into basic block structures:
  - heading-like lines beginning with `#`..`######`
  - unordered/ordered list lines
  - plain paragraph lines
- Render all block text at body font size.

## Phase 2: Apply style rules requested by product behavior
- Render heading lines with bold font weight only (no larger font size).
- Keep heading vertical spacing equal to normal paragraph spacing (no extra top/bottom margins).
- Render lists with explicit left indentation and optional list markers.
- Add inline emphasis parsing for `**bold**`, `__bold__`, `*italic*`, and `_italic_` without introducing heading-size changes.

## Phase 3: Validation and regression safety
- Add widget tests in `message_list_test.dart` to confirm:
  - heading-like text is rendered with body font size.
  - heading-like text has bold weight.
  - list items are indented relative to non-list text.
- Run targeted Flutter tests from the package directory.

# Acceptance Criteria
1. Assistant message containing `# Title` displays as bold text with the same font size as adjacent body text.
2. Heading-like lines do not have extra margins/padding compared to regular lines.
3. Markdown list items render with visible indentation.
4. Existing `MessageList` tests continue to pass.
5. New markdown rendering tests pass under `flutter test` in `apps/mobile_chat_app`.
