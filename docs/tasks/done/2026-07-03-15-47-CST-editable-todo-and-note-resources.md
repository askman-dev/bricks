# Editable Todo and Note Resources

## Background

Bricks needs lightweight editable resource types that users can keep inside their working context. The first two resource types are todo and note.

## Requirement

Todo and note resources must be editable. A todo resource lets the user mark an item done or undone. A note resource lets the user type and edit text using an embedded mature open-source lightweight Markdown editor.

## Acceptance Criteria

- Given a todo resource, when the user marks it done, then the todo visibly changes to the done state.
- Given a done todo resource, when the user marks it undone, then the todo visibly returns to the undone state.
- Given a note resource, when the user types into the note editor, then the note content is editable in place.
- Given a note resource, when the note editor is shown, then it uses an embedded mature open-source lightweight Markdown editing experience.
