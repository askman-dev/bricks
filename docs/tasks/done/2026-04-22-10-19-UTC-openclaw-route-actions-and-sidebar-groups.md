# OpenClaw route actions and sidebar groups plan

## Background
The chat composer and navigation drawer currently do not fully satisfy route-aware interaction requirements. In particular, the `@` action is non-interactive in default route mode, OpenClaw route-specific command presets are not populated, and the sidebar lacks a dedicated Skills group above Agents.

## Goals
1. Make route-linked composer actions behaviorally correct for `default` and `openclaw` routes.
2. Ensure OpenClaw slash command presets are available from official OpenClaw docs and selectable in UI.
3. Add a Skills section above Agents in the sidebar (empty state for now).
4. Cover the updated behavior with widget tests.
5. Keep code maps aligned with changed user-facing behavior.

## Implementation Plan (phased)
1. **Composer route actions**
   - Add explicit at-menu support in `ComposerBar` with route-specific menu content.
   - Wire default route `@` menu to existing agents list.
   - Wire OpenClaw `@` menu to a placeholder empty menu item (`待实现`).
2. **OpenClaw slash commands**
   - Populate a curated static slash command list in `chat_screen.dart` based on OpenClaw official slash commands documentation.
   - Keep current insert-on-select behavior in composer unchanged.
3. **Sidebar grouping**
   - Add a Skills section above Agents in `ChatNavigationPage` with an empty-state row.
4. **Validation & docs sync**
   - Add/adjust widget tests for composer and navigation groups.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` to reflect new visible behavior and risks.

## Acceptance Criteria
- In `openclaw` route, composer shows both `/` slash command action and clickable `@` action; clicking `@` opens a dropdown with `待实现` placeholder.
- In `default` route, composer shows clickable `@` action and dropdown items match available agents used by sidebar Agents section.
- Sidebar shows a Skills section above Agents with empty content state.
- Widget tests pass for the new composer and sidebar behaviors.
- Code maps are updated to reflect the new route/action behavior.
