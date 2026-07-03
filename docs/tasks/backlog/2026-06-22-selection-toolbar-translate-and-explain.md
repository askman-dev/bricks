# Selection Toolbar Translate and Explain Actions

## Confirmed Need

The selection toolbar should support a translate action alongside the existing copy and highlight actions.

After text is highlighted, the user should also see an explain action. Clicking explain should create a new thread and automatically send a prompt that asks the AI to explain the selected text using the surrounding context.

## Notes

- Current toolbar actions include copy and highlight.
- The translate action should be available from the selection toolbar.
- The explain action is tied to highlighted text, not just any empty selection state.
- The explain flow should preserve both the selected text and relevant context so the AI response is useful in the new thread.
- Exact toolbar placement, icon labels, prompt wording, context size, and thread naming behavior are not decided yet.
