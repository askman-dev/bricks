# Paste Clipboard Images into Chat Input

## Confirmed Need

When the user has a screenshot or image in the clipboard, the chat input should allow the user to paste it directly into the composer and ask a question with it.

Pasting an image should simulate the normal upload process so the user sees the same attachment progress, readiness, and failure states they would see when selecting or uploading an image file.

## Notes

- The source request specifically mentioned screenshots in the clipboard.
- The pasted image should become part of the current message draft, alongside any typed question.
- The UX should feel equivalent to uploading an image, not like inserting hidden or untracked clipboard data.
- The exact paste event handling, attachment storage path, progress UI, retry behavior, file naming, and supported image formats are not decided yet.
