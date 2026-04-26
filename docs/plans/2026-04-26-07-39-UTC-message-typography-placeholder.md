# Background
User requested two UI token adjustments in chat: increase message body typography and switch placeholder color to a white-family token from the existing design system.

# Goals
1. Use larger text style for chat message body content.
2. Replace composer placeholder color with an existing design-system white-family semantic color.
3. Validate with focused Flutter tests.

# Implementation Plan (phased)
1. Update message body text styles in `message_list.dart` from `bodyMedium` to `bodyLarge` (assistant and user message text).
2. Update composer placeholder semantic color in `chat_colors.dart` to use a design-system token from `AppColors` without introducing new values.
3. Run environment bootstrap and targeted tests for chat widgets.

# Acceptance Criteria
- User and assistant message body text render using `bodyLarge` in chat message list.
- Composer placeholder no longer uses tertiary text; uses the selected white-family design-system token.
- Relevant Flutter widget tests pass.
