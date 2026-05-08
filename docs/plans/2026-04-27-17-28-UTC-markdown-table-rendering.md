# Background
The mobile chat assistant currently supports a lightweight markdown subset (headings, lists, code fences, block quotes, inline styles/links) but does not render markdown table syntax. As a result, table source text is shown literally in messages, which harms readability for structured answers.

# Goals
- Render GitHub-style markdown tables (`|` row syntax + separator row) as visual table widgets in assistant messages.
- Keep existing markdown features and styles intact.
- Add regression coverage for table rendering in widget tests.

# Implementation Plan (phased)
## Phase 1: Parser and renderer extension
- Extend `_AssistantMarkdownText` line-walking logic to detect table blocks before paragraph/list parsing.
- Add a `_MarkdownTable` helper that parses a header row + separator row + data rows and normalizes column counts.
- Render parsed tables with Flutter `Table` wrapped in horizontal scroll for narrow screens.

## Phase 2: Validation and regression tests
- Add widget test coverage to verify table syntax is transformed into a rendered `Table` and cell text appears as expected.
- Ensure literal raw markdown table line text is no longer displayed for parsed table messages.

## Phase 3: Verification commands
- Initialize repo dev environment with `./tools/init_dev_env.sh`.
- Run targeted mobile app tests from package directory: `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`.

# Acceptance Criteria
- Assistant messages containing markdown tables render visually as table UI, not literal raw `|`-delimited text.
- Existing markdown behaviors (headings/lists/code/quote) remain functional.
- New widget tests for markdown table rendering pass.
