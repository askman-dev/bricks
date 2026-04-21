# Background
The current implementation supports issuing a single OpenClaw-oriented platform token from Settings (`Openclaw Token`) and uses `pluginId` as the token-scoping identity. This works for one plugin runtime but does not provide a user-facing concept of multiple target runtimes (“nodes”) such as:
- a local company computer OpenClaw runtime,
- a cloud runtime on AWS,
- and future additional plugin runtimes.

From code inspection, the current behavior is:
- Mobile app Settings exposes one token generation page and calls `GET /api/config/platform-token?pluginId=<...>` with a default plugin id (`plugin_local_main`).
- Node routing identity in backend platform APIs is `X-Bricks-Plugin-Id` + JWT claim `pluginId` + optional scoped `userId`.
- Chat async persistence stores `resolvedBotId`, `agentName`, `source`, etc. in message metadata, and the UI currently displays assistant attribution using `agentName` (which is currently set to `resolvedBotId`, so it often appears as `ask`).

The requested enhancement is to add a “Node” layer where each token belongs to one node name, and messages sent to a node are retrievable only by that node’s token (JWT algorithm unchanged).

# Goals
1. Introduce a first-class **Node** model (display name + stable identity) so users can manage multiple plugin endpoints under Settings.
2. Make platform tokens node-scoped by binding token issuance/verification to a node-owned plugin identity (without changing JWT signing algorithm/protocol family).
3. Ensure message delivery isolation: a token for Node A cannot read/ack/write Node B messages.
4. Add Settings UX for node management:
   - “节点” entry point,
   - empty-state “create first node” CTA,
   - auto-generated default names (`openclaw 1`, `openclaw 2`, …; extensible naming strategy including zodiac labels),
   - editable node names,
   - copy conveniences under each node.
5. Update chat message attribution so assistant items display **Node Name** instead of generic `ask` when message source is node-delivered.
6. Preserve backward compatibility/migration path for existing single-token users and currently deployed node_openclaw_plugin runtimes.

# Implementation Plan (phased)
## Phase 0: Domain framing and data model decisions
1. Define Node identity split:
   - `node_id` (stable storage identity, immutable),
   - `display_name` (editable label shown in UI).
2. Define node-to-plugin binding strategy:
   - Option A (recommended): one stable `pluginId` per node persisted server-side.
   - Option B: derive pluginId from node_id deterministically.
3. Keep token algorithm unchanged (existing JWT signing/verification), but include `pluginId` corresponding to node binding.
4. Confirm compatibility policy:
   - Existing `plugin_local_main` treated as a migrated default node,
   - no breaking change for old clients during rollout window.

## Phase 1: Backend data layer and migration
1. Add DB migration(s) in `apps/node_backend/src/db/migrations/` for node entities, for example:
   - `platform_nodes` table:
     - `id` (PK),
     - `user_id`,
     - `node_id` (unique per user),
     - `display_name`,
     - `plugin_id` (unique per user),
     - timestamps,
     - optional soft-delete/archive field.
2. Add indexes and constraints:
   - uniqueness for `(user_id, node_id)`, `(user_id, plugin_id)`,
   - non-empty normalized display_name.
3. Add a migration routine or lazy bootstrap path to create a default node for users without nodes.

## Phase 2: Backend services and APIs
1. Add `platformNodeService` (or equivalent) in `apps/node_backend/src/services/`:
   - list nodes,
   - create node with generated default name,
   - rename node,
   - resolve node by `nodeId` and/or `pluginId`.
2. Extend config routes (`apps/node_backend/src/routes/config.ts`):
   - replace/augment `GET /config/platform-token` with node-aware issuance (`nodeId` parameter).
   - response includes node metadata (`nodeId`, `nodeName`, `pluginId`, `token`, `scopes`, `baseUrl`, `expiresIn`).
3. Add dedicated node management routes (recommended under `/api/config/nodes` or `/api/platform/nodes`):
   - `GET /nodes` list,
   - `POST /nodes` create,
   - `PATCH /nodes/:nodeId` rename,
   - optional `DELETE /nodes/:nodeId` (only if product wants archival/removal now).
4. Ensure token issuance rejects unknown/foreign nodeId and always signs token with node-owned pluginId.

## Phase 3: Platform auth and isolation guarantees
1. Keep `issuePlatformAccessToken` algorithm unchanged, but enforce that token `pluginId` comes from node binding.
2. Maintain existing middleware checks in `authenticatePlatformApiKey`:
   - JWT `pluginId` must match header `X-Bricks-Plugin-Id`.
3. Strengthen platform integration service queries (`platformIntegrationService`) to remain plugin-scoped and user-scoped.
4. Add explicit guard tests for cross-node access attempts:
   - token from node A + header for node B => forbidden,
   - node A token cannot ACK/patch messages created under node B plugin scope.

## Phase 4: Mobile app settings UX for Nodes
1. Add a new Settings entry: `节点` (Node Settings).
2. Build node list screen:
   - empty state with “创建第一个节点” button,
   - populated list with each node card showing name, plugin id summary, copy actions.
3. Create node flow:
   - default naming generator (`openclaw 1`, `openclaw 2`, …),
   - optional alternative naming strategy hook (zodiac sequence) behind utility/service.
4. Rename flow:
   - inline or modal edit with validation.
5. Token actions per node:
   - fetch/generate token for selected node,
   - copy token,
   - copy install instructions with node-specific pluginId/token.
6. Refactor existing `OpenclawTokenSettingsScreen` into node-centric UI or keep as backward-compatible subpage delegated from node details.

## Phase 5: Chat attribution update (show Node Name instead of ask)
1. Decide attribution source of truth for assistant messages:
   - prefer `metadata.nodeName` when source is node-delivered,
   - fallback to `agentName` for legacy records.
2. Update server write paths (`chat.ts`, `platformIntegrationService.ts`) to include node metadata (`nodeId`, `nodeName`) when messages originate from platform/plugin pipeline.
3. Update `ChatHistoryApiService._messageFromServerMap` and/or `ChatMessage` mapping to preserve and expose node attribution.
4. Update `MessageList` rendering logic so assistant chip shows node name for node-origin messages (instead of `ask`).
5. Ensure historical compatibility for records without node metadata.

## Phase 6: Plugin/runtime compatibility (node_openclaw_plugin)
1. Update plugin setup docs and runtime expectations:
   - each runtime uses node-specific `BRICKS_PLUGIN_ID` + token.
2. No JWT algorithm changes in plugin claim parser; only values differ by node.
3. Optional: improve plugin logs to include node identity for observability.

## Phase 7: Tests, regression checks, and docs/code map updates
1. Backend tests:
   - route tests for node CRUD and node-scoped token issuance,
   - middleware tests for cross-node rejection,
   - integration-service tests for plugin/user isolation.
2. Flutter tests:
   - settings navigation includes 节点 entry,
   - empty-state/create/rename/copy interactions,
   - node-aware token instruction rendering,
   - message list attribution renders node name.
3. Validation commands:
   - `./tools/init_dev_env.sh`
   - `cd apps/node_backend && npm test`
   - `cd apps/mobile_chat_app && flutter test`
   - optional targeted checks: `cd apps/mobile_chat_app && flutter analyze`
4. Update code maps (`docs/code_maps/feature_map.yaml`, `docs/code_maps/logic_map.yaml`) after implementation because feature entry paths, business logic, and tests will change.

# Acceptance Criteria
1. User can create multiple nodes in Settings, starting from empty-state CTA, and can rename each node with persisted result.
2. Each node can issue/copy its own token and install instructions, and returned token payload clearly indicates node binding.
3. A message addressed to a node is only retrievable/acknowledgeable/updateable by that node’s token scope (pluginId isolation enforced).
4. Existing JWT algorithm/protocol remains unchanged; only claim values (pluginId) reflect node binding.
5. In chat list UI, assistant messages generated via node/plugin path display the corresponding Node Name instead of generic `ask` when node metadata is available.
6. Legacy users with pre-existing single-token setup can continue working via migrated/default node behavior.
7. Automated tests covering node lifecycle, token scoping, and UI attribution pass in CI/local validation commands.
