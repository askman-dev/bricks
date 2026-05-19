# Navigation Resources Highlights

## Background

The chat navigation drawer has a Resources tab that currently lists todo lists and asset tables. Text highlights are persisted through `/api/resources/highlights` and rendered in assistant messages, but they are not visible from the Resources navigation surface.

## Goals

- Show saved text highlights in the chat navigation Resources tab alongside other atomic resources.
- Sort Resources tab items by update time descending across all resource types.
- Add a type filter at the top of the Resources tab.
- Preserve the existing todo-list and asset-table resource behavior.
- Update code maps because the change affects a user-visible navigation entry point and highlight resource behavior.

## Implementation Plan

1. Extend the chat navigation resource model with a text-highlight resource type and an `updatedAt` sort key.
2. Update the Resources tab to sort atomic resources by update time descending and expose type filter chips.
3. Feed loaded highlights from `ChatScreen` into the navigation resources collection.
4. Add or update widget tests covering highlight resources, sorting, filtering, and preview behavior.
5. Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml`.

## Acceptance Criteria

- Saved highlights appear in the Resources tab after highlights are loaded.
- Resources are not grouped by type; all resource items are shown as atomic rows sorted by newest update time first.
- The Resources tab has a top filter that can narrow the list by resource type.
- Highlight resources use a distinct highlight icon and show the highlighted text as the resource title.
- Tapping a highlight resource opens a preview page identifying it as a text highlight.
- Existing todo-list and asset-table resources still render with their current labels and icons.

## Validation Commands

- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null && echo "code maps yaml ok"`
