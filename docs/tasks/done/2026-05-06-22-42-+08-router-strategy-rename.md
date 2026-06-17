# Router Strategy Rename

## Background

The current chat routing model uses `router: default | openclaw`. This mixes two concepts: dispatch strategy and concrete external platform. `default` currently means Bricks handles the response locally, while `openclaw` means the message is dispatched to a plugin-backed remote node. Future plugin-backed platforms such as Hermes should use the same remote plugin dispatch strategy without adding platform names to the router enum.

The branch also adds metadata fields for default-router built-in node identity. The next step should simplify those metadata fields while preserving current business behavior.

## Goals

- Rename router semantics from platform-specific values to dispatch-strategy values.
- Use `local` for Bricks-managed direct execution and `plugin` for plugin-backed remote dispatch.
- Keep concrete platform identity, such as OpenClaw or future Hermes, on platform node/plugin configuration instead of the router enum.
- Preserve existing default and OpenClaw behavior during migration.
- Remove redundant target metadata fields that duplicate router semantics.

## Implementation Plan

1. Define the target router vocabulary:
   - Canonical `ChatRouter` values become `local` and `plugin`.
   - Legacy input values `default` and `openclaw` remain accepted during migration and normalize to `local` and `plugin`.
2. Update backend router parsing and persistence:
   - Normalize `default -> local` and `openclaw -> plugin` at API boundaries.
   - Continue to support existing database rows during read/resolve until a migration is applied.
   - Add or update migration logic for stored `chat_scope_settings.router` values.
3. Simplify chat respond target metadata:
   - Keep `targetNodeId`, `targetNodeName`, and `targetPluginId`.
   - Remove `targetSourcePlatform` and `resolvedRouteKind` from newly written metadata.
   - Do not add `targetNodeKind` unless a future router maps to multiple target node categories.
4. Keep platform identity in node/plugin records:
   - OpenClaw-specific behavior remains attached to platform node/plugin configuration.
   - Future Hermes nodes should also use `router: plugin` and differ by plugin/platform metadata, not router enum.
5. Update Flutter router models and API payloads:
   - Rename UI enum values to local/plugin semantics.
   - Preserve labels such as `Bricks Default` and `OpenClaw` at presentation boundaries.
   - Keep thread inheritance behavior unchanged.
6. Update tests and code maps:
   - Backend tests should assert `local/plugin` router behavior and metadata shape.
   - Flutter tests should assert legacy parsing compatibility and canonical outgoing values.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` because this changes chat routing business logic and API contracts.

## Acceptance Criteria

- Existing saved `default` scope settings resolve as `local` without changing user-visible behavior.
- Existing saved `openclaw` scope settings resolve as `plugin` and still dispatch to the configured OpenClaw node.
- New scope-setting writes use canonical `local` or `plugin` router values.
- Default Bricks chat still responds through local backend execution.
- OpenClaw chat still creates the dispatch placeholder and waits for plugin-backed remote handling.
- Chat message metadata still includes target node identity, but newly written messages no longer include `targetSourcePlatform` or `resolvedRouteKind`.
- Future plugin-backed platforms can reuse `router: plugin` without adding a new router enum value.
- Code maps are updated for the routing contract change.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test -- --run src/routes/chat.test.ts src/services/chatRouterService.test.ts`
- `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart test/chat_topology_and_task_protocol_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
