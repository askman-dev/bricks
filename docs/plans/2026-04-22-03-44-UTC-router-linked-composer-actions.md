# Background
The chat composer currently shows a route button and a static configuration button with fixed menu items. Product requirements now require route-aware action buttons: default route should expose the config button with current model visibility, generic non-default routes should hide config by default, and the OpenClaw route should expose dedicated slash-command tooling.

# Goals
1. Make composer actions dynamically depend on the effective router selection.
2. Update the configuration menu to show the currently effective model under the “模型” item.
3. Remove “Agents” and “新上下文” entries from the configuration menu.
4. Add an OpenClaw slash-command button that inserts selected slash commands into the input box.
5. Keep route-selection behavior intact and covered by widget tests.

# Implementation Plan (phased)
1. **Composer widget API refactor**
   - Replace the single optional `routerAction` slot with a flexible `leadingActions` list.
   - Add optional model display text and slash command list support.
   - Update menu enum/actions to remove deprecated entries.
2. **Chat screen wiring**
   - Build route-dependent leading actions in `ChatScreen` based on `_effectiveRouterForScope()`.
   - Preserve existing route picker button.
   - For `default` route, render config button only.
   - For `openclaw`, render slash command button plus config button.
   - For unknown future routes, render no config button by default.
3. **OpenClaw slash command presets**
   - Add a curated initial slash command list based on OpenClaw docs and bind selection to composer input insertion.
4. **Tests and map updates**
   - Update `composer_bar_test.dart` for API and behavior changes.
   - Run Flutter tests from package directory after environment bootstrap.
   - Evaluate code map impact and update maps if feature/logic index changed.

# Acceptance Criteria
- Selecting default route shows the config button with menu item “模型” plus subtitle of the currently selected model.
- Config menu no longer includes “Agents” or “新上下文”.
- Selecting OpenClaw route shows a slash button; picking a slash command inserts command text into the composer input.
- For non-default non-openclaw routes, config button is hidden by default.
- `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart` passes after `./tools/init_dev_env.sh`.
