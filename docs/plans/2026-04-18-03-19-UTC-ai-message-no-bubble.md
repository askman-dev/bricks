# Background
The mobile chat message list currently renders both user and assistant messages inside rounded bubble containers. For assistant replies, this consumes horizontal space due to bubble padding and creates a denser layout than desired.

# Goals
- Remove the bubble visual treatment for assistant messages in the conversation list.
- Reduce horizontal spacing for assistant output so more text fits per line.
- Keep user message bubble style and behavior unchanged.

# Implementation Plan (phased)
1. Update `MessageList` assistant row rendering to use plain text content without background bubble decoration.
2. Keep user branch on the existing bubble styling path so outgoing message visuals are unchanged.
3. Adjust/add widget tests to verify assistant layout width increases while user bubble constraints remain.

# Acceptance Criteria
- Assistant messages no longer show a rounded/background bubble container in the message list.
- Assistant messages have less horizontal inset than before and display a wider content area.
- User messages still render with existing bubble style and compact width constraints.
- Validation command passes: `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`.
