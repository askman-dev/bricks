# Background

The chat drawer currently exposes a standalone `Manage Agents` action and only supports a non-collapsible channel section. The requested UX requires agent management to move into Settings, and the drawer should show an `Agents` group with collapsible behavior and fallback empty-state guidance.

# Goals

- Move `Manage Agents` entry from drawer navigation into Settings, directly below Model Settings.
- Add a collapsible `Agents` section above the channel section in the drawer.
- Show existing agents in the new drawer section, or show `在设置中新建 Agents` when empty.
- Add a config icon+text button on the `Agents` section header that currently shows a toast saying `未开发的功能`.
- Make the channel section collapsible by tapping the section title.

# Implementation Plan (phased)

## Phase 1: Drawer data model and UI structure

1. Extend chat navigation drawer input model to accept agent items.
2. Convert drawer widget to stateful to track expanded/collapsed state for `Agents` and `频道` groups.
3. Remove drawer `Manage Agents` list tile.
4. Render `Agents` section above channel section, with:
   - tappable header title to toggle expand/collapse,
   - right-side config icon+text button,
   - toast on config button tap with `未开发的功能`.
5. Keep channel create button and list behavior under a collapsible channel header.

## Phase 2: Screen integration

1. Pass current loaded agent definitions from `ChatScreen` into drawer agent items.
2. Update Settings screen to add `Manage Agents` list tile under `Model Settings`, navigating to `AgentsScreen`.

## Phase 3: Validation and regression checks

1. Update/extend widget tests for drawer behavior:
   - no standalone `Manage Agents` tile,
   - agents header and empty-state text,
   - expand/collapse behavior for agents and channels,
   - config button shows expected toast.
2. Run targeted Flutter tests.

# Acceptance Criteria

- In drawer, `Manage Agents` no longer appears as a standalone list item.
- Drawer shows an `Agents` section above `频道` and displays loaded agents by name.
- When no agents exist, drawer shows `在设置中新建 Agents` in Agents section.
- Tapping `Agents` title toggles section expansion/collapse.
- Agents header config icon+button exists; tapping it shows a snackbar/toast with `未开发的功能`.
- Tapping `频道` title toggles section expansion/collapse.
- Settings screen contains `Manage Agents` item immediately below `Model Settings` and navigates to Agents screen.
