# Tool Call Thinking Group

## Background

Tool call result messages can render large JSON payloads inline in the chat stream. Users need to know that the assistant is processing, but the raw tool type, arguments, and payload are diagnostic details rather than primary chat content.

## Goals

- Collapse adjacent tool call messages into one compact inline status object.
- Use the user-facing labels `正在思考 completed/total` while the group is active and `思考过程 completed/total` when the group is complete.
- Do not show tool names, tool types, arguments, or JSON payloads in the outer chat stream.
- Keep non-adjacent tool groups separate.

## Implementation Plan

1. Identify agent-loop tool messages in `MessageList`, including tool start and tool result phases.
2. Group only consecutive tool messages during message list rendering.
3. Render a single status row for each group with completed and total counts.
4. Keep reasoning and step-text agent-loop phases on their existing rendering path.
5. Add widget tests for active/completed groups, adjacent merging, and non-adjacent separation.

## Acceptance Criteria

- A single in-progress tool displays `正在思考 0/1`.
- A completed tool displays `思考过程 1/1`.
- Adjacent completed tools display one row, for example `思考过程 2/2`.
- Non-adjacent tool calls display separate rows.
- Raw `Tool: ...` JSON content is not visible in the chat stream for grouped tool calls.

## Validation Commands

- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
