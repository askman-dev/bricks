# Resource Item Meta Icon Layout

## Background

The Resources tab currently renders each resource item as a left/right row with
a large leading icon and text content on the right. The requested layout should
make each item text-first, with the resource type shown as the second line and a
small type icon placed directly before that metadata text.

## Goals

- Remove the large leading icon from resource list items.
- Limit resource titles to two lines with an ellipsis when overflowing.
- Render the resource type as an inline metadata row under the title.
- Place a small resource-type icon immediately before the metadata text.
- Preserve resource ordering, filtering, and tap behavior.

## Implementation Plan

1. Update the Resources tab item builder in `ChatNavigationPage`.
2. Replace `ListTile.leading` with a compact subtitle row containing the icon
   and resource type label.
3. Limit title text to two lines with `TextOverflow.ellipsis`.
4. Add a widget test that verifies resource icons are rendered inside the tile
   subtitle area rather than as leading icons.

## Acceptance Criteria

- A resource item title starts at the normal tile text inset, not to the right
  of a large leading icon.
- The second line shows a small icon followed by the resource type label, such
  as `Text Highlight`.
- Long resource titles are capped at two lines and overflow with an ellipsis.
- Existing Resources tab sorting, filtering, and preview navigation continue to
  work.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
