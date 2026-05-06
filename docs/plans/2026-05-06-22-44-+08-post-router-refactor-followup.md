# Post Router Refactor Follow-up

## Background

The router model should first be clarified separately so that `router` means dispatch strategy only: `local` for Bricks-managed direct execution and `plugin` for plugin-backed remote dispatch. This plan assumes that router refactor is already complete and does not include the router rename or migration work.

After that refactor, the remaining feature work is not to add another router kind. The remaining work is to make Bricks local execution and plugin-backed execution share a clearer target model, expose built-in Bricks targets consistently, and prepare instruction governance without coupling those concepts to OpenClaw-specific names.

## Goals

- Expose Bricks built-in local targets consistently in backend and frontend.
- Keep plugin platform identity outside the router enum.
- Preserve current local Bricks response behavior and plugin/OpenClaw dispatch behavior.
- Make scope settings and target metadata easier to consume after router semantics are clarified.
- Continue instruction governance work without changing the already implemented channel/thread instructions behavior.

## Implementation Plan

1. Define the built-in Bricks target model after router refactor.
   - Keep `node_builtin_default` as the stable built-in target id.
   - Keep `Bricks Default` as the display name.
   - Treat this as the default local execution target, not as a separate router value.
   - Add a compact shared type/helper for local target identity if needed.

2. Normalize target metadata after router refactor.
   - Newly written chat message metadata should include `targetNodeId`, `targetNodeName`, and `targetPluginId`.
   - Do not reintroduce `targetSourcePlatform`, `resolvedRouteKind`, or `targetNodeKind` unless a later feature creates a real need.
   - Ensure local responses write the built-in target id/name and plugin responses write the plugin node id/name/plugin id.

3. Expose built-in Bricks target in target-selection surfaces.
   - Backend node/target listing should make the built-in local target available as a read-only target.
   - Frontend route/target menus should present `Bricks Default` as the local target and plugin nodes separately.
   - The UI should still label concrete plugin nodes by their display name and plugin platform where useful, for example OpenClaw.

4. Align scope-setting responses with resolved target semantics.
   - Scope-setting reads should keep the persisted router strategy and node id.
   - Where the UI needs display-ready information, return or derive the resolved target id/name after thread inheritance and fallback.
   - For thread-follow-channel mode, make the effective target unambiguous without storing duplicate thread settings.

5. Preserve existing instruction behavior and layer future governance on top.
   - Channel and section instructions already save, hydrate, and apply to local/default responses.
   - Keep that behavior unchanged.
   - Add a future-ready prompt assembly boundary for local Bricks execution: base system prompt, selected agent prompt, channel instructions, section instructions.
   - Do not apply local prompt assembly to plugin dispatch unless plugin-specific support is explicitly designed.

6. Add instruction governance as a separate capability.
   - Define inheritance/override semantics for local execution: built-in target defaults -> channel -> section.
   - Add audit fields or audit events for instruction changes.
   - Add AI-assisted instruction edit endpoints only after the storage and audit model is clear.

7. Update tests and code maps.
   - Add backend tests for built-in target listing/read-only behavior and metadata shape.
   - Add frontend tests for target menu presentation and legacy hydrated scope behavior after router refactor.
   - Add tests for effective target resolution with thread inheritance and missing plugin nodes.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` because target resolution and chat routing entry points are affected.

## Acceptance Criteria

- Bricks local execution still works with no plugin nodes configured.
- Plugin/OpenClaw dispatch still works when a valid plugin node is configured.
- When a plugin node is missing, existing fallback/error behavior remains unchanged.
- New chat message metadata records the actual target id/name/plugin id without redundant route-kind/source-platform fields.
- The built-in Bricks target is visible where users choose or inspect chat targets, but it is read-only and requires no import/install flow.
- Thread-follow-channel target resolution is clear to the UI and does not require duplicated settings.
- Existing channel and section instructions continue to save, hydrate, clear, and apply to local Bricks responses.
- Instruction governance is introduced behind clear storage/audit semantics, not mixed into router naming.
- Code maps are updated after implementation.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test -- --run src/routes/chat.test.ts src/routes/config.test.ts src/services/chatRouterService.test.ts`
- `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart test/chat_topology_and_task_protocol_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
