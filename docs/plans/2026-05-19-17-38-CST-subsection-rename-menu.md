# Subsection Rename Menu

## Background

The chat header subsection dropdown currently shows placeholder actions for subsection rename and archive. Users need the menu to be grouped, hide current-section actions while in the main section, and allow a child subsection to be renamed from the dropdown.

## Goals

- Rework the subsection dropdown into the requested groups.
- Enable subsection rename for non-main subsections.
- Keep main section immutable from this menu.
- Persist renamed subsection labels through the existing chat naming API shape without breaking channel rename behavior.

## Implementation Plan

1. Update the mobile chat header menu builder so the first group contains only "新建子区", the second group appears only for child subsections with a small "当前组" title and rename/archive actions, and the final group lists main plus child subsections.
2. Add a subsection rename dialog using the same validation style as channel rename.
3. Archive child subsections locally from the current channel list and return the user to the main section.
4. Extend chat name persistence to support optional `threadId` while preserving existing channel-only callers.
5. Update code maps and focused tests for API serialization and route behavior.

## Acceptance Criteria

- In the main section, the subsection dropdown shows "新建子区" and the section list but does not show "当前组", "改名", or "归档".
- In a child subsection, the dropdown shows "当前组" as a small muted group title above "改名" and "归档".
- Choosing "改名" opens a dialog, validates blank and duplicate names, and updates the subsection label after saving.
- Choosing "归档" removes the current child subsection from the dropdown and switches back to "主区".
- Subsection display names can be saved and loaded with `threadId` without changing existing channel name behavior.

## Validation Commands

- `./tools/init_dev_env.sh --flutter-home /Users/admin/.local/tools/flutter --no-doctor`
- `cd apps/mobile_chat_app && dart format lib/features/chat/chat_screen.dart lib/features/chat/chat_history_api_service.dart test/chat_history_api_service_test.dart`
- `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart`
- `cd apps/node_backend && npm test -- src/routes/chat.test.ts`
- `npx js-yaml docs/code_maps/feature_map.yaml >/dev/null && npx js-yaml docs/code_maps/logic_map.yaml >/dev/null`
