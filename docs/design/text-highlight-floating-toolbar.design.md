# Text Highlight Floating Toolbar

## Component

Text Highlight Floating Toolbar

## Purpose

Provide a compact contextual toolbar for assistant-message text highlights. The toolbar appears close to the user's text interaction and offers only actions that apply to the current text state.

## Surfaces

- The toolbar uses an elevated overlay surface.
- The toolbar is not a page section, card, or nested card.
- The toolbar should reuse existing theme overlay colors and text colors rather than introducing feature-local color literals.

## Trigger States

### Selected Text

When the user selects text in an assistant message, show the toolbar near the pointer-up location.

Actions:

- `复制`: copy the selected text.
- `划线`: create a highlight for the selected range.
- `删除划线`: replace `划线` when the selected range matches an existing highlight.

### Existing Highlight

When the user taps an existing highlighted span, show the same toolbar style near the tap location.

Actions:

- `复制`: copy the highlighted text.
- `删除划线`: delete the tapped highlight.

## Placement

- Position the toolbar above the interaction point when space allows.
- Clamp the toolbar within the viewport using an 8 px edge margin.
- Do not use a full-width bottom sheet or a system corner context menu for this interaction.

## Behavior

- Toolbar actions fire on pointer down so Flutter Web selection changes cannot remove the toolbar before the action runs.
- Tapping outside the toolbar dismisses it.
- Successful copy dismisses the toolbar.
- Successful delete dismisses the toolbar.
- The toolbar should not appear for user-message bubbles.

## Highlight Range Semantics

- Multiple persisted highlight records may overlap or touch.
- Rendering treats overlapping or adjacent records as a visual union so text is never duplicated.
- The stored records remain compatible with the existing highlight API.

## Visual Constraints

- Radius: use the compact overlay radius already used by chat floating controls.
- Spacing: use `BricksSpacing.xs` inside the toolbar.
- Minimum button size: 52 x 36 px.
- Text labels must remain short and fit without wrapping.
