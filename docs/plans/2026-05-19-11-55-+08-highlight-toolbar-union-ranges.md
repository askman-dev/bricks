# Highlight Toolbar And Union Ranges

## Background

Text highlight creation now works end to end and persisted highlights survive reloads. Two interaction and rendering gaps remain:

- Tapping an existing highlighted span should show the same compact floating toolbar style used for selected text, with Copy and Delete Highlight actions.
- When a new highlight overlaps or touches an existing highlight, the visual result should behave like the union of those ranges. The current renderer can process overlapping ranges independently and duplicate text fragments.

Cross-paragraph selection toolbar behavior is explicitly out of scope for this change.

## Goals

- Show a compact floating toolbar with `复制` and `删除划线` when the user taps an existing highlighted span.
- Reuse the same floating toolbar visual language and pointer-down action behavior as the selection toolbar.
- Merge overlapping or adjacent highlight ranges before rendering so repeated highlight coverage never duplicates text.
- Keep persisted highlight records compatible with the existing backend API.
- Document the toolbar behavior in a design-md style design note.

## Implementation Plan

1. Update highlight tap interaction.
   - Replace the old popup menu for tapped highlighted spans with a transparent `showGeneralDialog` overlay.
   - Position the overlay near the tap point and clamp it within the viewport.
   - Render the same `_SelectionFloatingToolbar` component with `复制` and `删除划线`.
   - Trigger copy/delete on pointer down, matching the fixed selection toolbar behavior.

2. Merge highlight ranges before rendering.
   - Convert stored offset highlights and legacy selected-text highlights into `_HighlightRange` values as before.
   - Sort ranges by start/end.
   - Coalesce overlapping or adjacent ranges into one visual range.
   - Preserve a representative highlight id for delete actions and concatenate selected text only for copy fallback.

3. Strengthen tests.
   - Add a widget test for overlapping highlights that verifies text is not duplicated.
   - Add a widget test that tapping a highlighted span shows `复制` and `删除划线` and calls the delete callback.
   - Keep the existing Chrome selection toolbar tests.

4. Add design-md documentation.
   - Create a small design note under `docs/design/` describing the floating toolbar's trigger states, actions, placement, dismissal, and visual tokens.
   - Reference the design note from code maps for the text highlight feature.

5. Update code maps and validate.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml`.
   - Run Flutter format, analyzer, and focused tests.
   - Validate code map YAML.

## Acceptance Criteria

- Tapping an existing highlighted span opens a floating toolbar with `复制` and `删除划线`.
- Tapping `复制` from that toolbar copies the highlighted text.
- Tapping `删除划线` invokes the delete callback for the tapped highlight.
- Overlapping, contained, or adjacent highlight records render as one continuous visual highlight without duplicated text.
- Existing non-overlapping highlights still render in the correct positions.
- The design note documents the floating toolbar in a reusable design-md format.

## Validation Commands

- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH dart format lib/features/chat/widgets/message_list.dart test/message_list_test.dart test/highlight_selection_toolbar_web_test.dart`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter test test/message_list_test.dart test/highlight_selection_toolbar_web_test.dart`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter test -d chrome test/highlight_selection_toolbar_web_test.dart`
- `cd apps/mobile_chat_app && PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter analyze`
- `ruby -e "require 'yaml'; YAML.load_file('docs/code_maps/feature_map.yaml'); YAML.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps yaml ok'"`
