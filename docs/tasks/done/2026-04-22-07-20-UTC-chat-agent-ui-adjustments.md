# Chat Agent UI Adjustments Plan

## Background
The chat UI currently supports `@agent` mention insertion inside the composer text field and shows an Agents section in the sidebar with a group-level configuration button. The requested behavior is to remove composer `@` mention mechanics, associate `@` visibility with router selection in the action row, and update sidebar agent interactions to focus on per-agent prompt preview plus explicit actions.

## Goals
1. Remove `@` mention parsing/insertion and `@` hint text from the composer input area.
2. Show an `@` marker next to the router action only when the effective route is the default route.
3. Remove the sidebar Agents group-level config button.
4. Make each sidebar agent row open a prompt preview page with two actions:
   - 修改配置 (navigates to existing manage-agents configuration page)
   - 发起对话 (selects this agent for the current conversation)
5. Keep current chat/channel behavior intact.

## Implementation Plan (phased)
### Phase 1: Composer behavior and layout
- Refactor `ComposerBar` to remove mention state, filtering, insertion logic, and mention popup rendering.
- Adjust input hint and icon behavior to avoid embedding `@` in text field UX.
- Add a new boolean prop controlling whether an `@` marker is rendered between router and config buttons.

### Phase 2: Sidebar agent interaction flow
- Extend sidebar agent item model to carry prompt content.
- Remove the Agents header config button.
- Add per-agent tap behavior to open a prompt detail screen.
- Implement prompt detail screen with two bottom actions: 修改配置 and 发起对话.

### Phase 3: Chat screen wiring and regression checks
- Wire `showRouteAtMarker` to router effective state in `ChatScreen`.
- Wire sidebar callbacks for opening configuration and selecting active agent from prompt detail action.
- Run targeted Dart/Flutter analysis/tests for touched chat widgets.

## Acceptance Criteria
- Composer input no longer auto-detects `@` mentions and no mention dropdown appears while typing.
- Composer hint text contains no `@` symbol.
- When effective router is default, an `@` marker appears to the right of the router button and left of the config button; it is hidden on non-default router.
- Sidebar Agents section has no header-level config button.
- Tapping an agent in sidebar opens a prompt page that displays prompt text and includes buttons: 修改配置 and 发起对话.
- 修改配置 opens the existing agent configuration flow; 发起对话 sets the active chat agent.
