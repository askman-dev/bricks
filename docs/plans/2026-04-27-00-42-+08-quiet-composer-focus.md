# Quiet Composer Focus Border

## Background
The chat composer currently switches to a stronger border token when the text field gains focus. The requested visual direction is quieter: focusing the input should not create a highlighted border.

## Goals
- Keep the composer border visually stable across focused and unfocused states.
- Remove now-unused focus-border color alias if no other widget consumes it.
- Avoid adding new color tokens.

## Implementation Plan (phased)
1. Change `ComposerBar` to always use `chatColors.composerBorder`.
2. Remove `ChatColors.composerBorderFocus` if it becomes unused.
3. Run formatting and mobile Flutter validation.

## Acceptance Criteria
- Focusing the composer input does not change the border color.
- `ChatColors` does not expose unused focus-border aliases.
- Validation commands pass.
