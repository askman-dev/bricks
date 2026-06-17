# Background

The current OpenClaw integration supports multiple platform nodes per user, but OpenClaw-routed chat messages are not addressed to a specific node. Because `/api/v1/platform/events` currently scopes pending user messages only by user identity, multiple OpenClaw nodes can receive and respond to the same chat message.

# Goals

1. Route each OpenClaw chat scope to exactly one selected node.
2. Ensure only the targeted node can read and process the pending chat event.
3. Preserve backward compatibility for scopes that do not yet have an explicit node selection.
4. Keep node attribution visible in the chat experience and validated by tests.

# Implementation Plan

## Phase 1

Extend backend chat scope settings to store an optional `nodeId` for OpenClaw scopes, with migration coverage and route/service updates.

## Phase 2

Update chat respond handling to accept a selected `nodeId`, resolve it to the owning platform node/plugin, and stamp OpenClaw-bound user messages with target node/plugin metadata used by platform event delivery.

## Phase 3

Update platform event and message-write paths so node/plugin isolation is enforced for reads and follow-up writes.

## Phase 4

Update the mobile chat UI to load available platform nodes, let the user choose the active OpenClaw node for the current scope, persist that selection through scope settings, and include it in `/api/chat/respond`.

## Phase 5

Add or update backend and Flutter tests, then update the code maps because routing entry points, persisted scope behavior, and test coverage will change.

# Acceptance Criteria

1. OpenClaw chat scopes can persist an optional selected `nodeId` per channel or thread.
2. `/api/chat/respond` forwards OpenClaw work to only the selected node, or the default node when no selection exists.
3. `/api/v1/platform/events` returns a pending chat message only to the targeted node/plugin scope.
4. Platform message writes remain node/plugin-scoped for the targeted conversation flow.
5. The mobile chat UI exposes and persists the active OpenClaw node for the current scope.
6. Validation commands complete successfully: `cd apps/node_backend && npm test`, `./tools/init_dev_env.sh`, and `cd apps/mobile_chat_app && flutter test`.
