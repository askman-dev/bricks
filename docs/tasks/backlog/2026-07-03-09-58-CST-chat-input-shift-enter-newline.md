# Chat Input Shift+Enter Inserts a New Line

## Background

In the chat composer, typing with `Shift+Enter` currently sends the message.
This is surprising when the user is editing a multi-line message, because the
common expectation is that `Shift+Enter` inserts a line break while plain
`Enter` sends.

## Requirement

Update the chat input behavior so `Shift+Enter` inserts a new line in the
current draft instead of sending the message.

## Acceptance Criteria

- Given the user is typing in the chat input, when they press `Shift+Enter`,
  then the current message draft gains a new line and is not sent.
- Given the user is typing in the chat input, when they press `Enter` without
  `Shift`, then the existing send behavior continues to work.
- Given the current draft contains multiple lines, when the user sends it, then
  the message content preserves the intended line breaks.

