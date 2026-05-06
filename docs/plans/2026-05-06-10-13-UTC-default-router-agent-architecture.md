# Background

In the current chat routing model, the `openclaw` router can bind to a concrete node (`nodeId`) and carries agent-style semantics through that node. By contrast, the `default` router mostly follows built-in logic (the default branch in `/api/chat/respond`) and is not modeled as a first-class node/agent entity.

This creates product-level inconsistencies:

- Channel and thread instructions can be saved, but they are not represented consistently under a unified “router == agent target” model.
- Observability metadata for default routing is not aligned between frontend and backend.
- Future AI-assisted instruction management (inheritance, overrides, auditing) is constrained by the lack of default-router identity.

The target is to make the default router equivalent to a built-in agent node: always available, no import, no plugin installation.

# Goals

1. Model the default router as a built-in virtual node with stable ID and display name.
2. Preserve current UX: every user has it by default, with no plugin setup.
3. Align expressiveness with OpenClaw node routing to support future AI instruction editing for channels/threads.
4. Keep existing OpenClaw routing/plugin behavior intact.

# Implementation Plan (phased)

## Phase 1: Domain model alignment (Backend)

1. Define built-in default node constants (e.g. `node_builtin_default`) and source platform (e.g. `builtin`).
2. Introduce a unified resolved target shape in routing resolution:
   - `router`
   - `nodeId`
   - `nodeKind` (`builtin_default` / `platform_openclaw`)
   - `agentName`
3. In `/api/chat/respond`, emit consistent user/assistant metadata (including `targetNodeId/targetNodeName`) for both default and OpenClaw.

## Phase 2: Config and presentation alignment (Config + Chat UI)

1. Add a read-only built-in default node to node-list APIs (not renameable or deletable).
2. Present default in the route picker with node-style UI (e.g. “Bricks Default (Built-in)”), while still being always available.
3. Keep existing channel/thread instruction editors; optionally return `resolvedNodeId` from scope-setting reads (built-in node ID for default).

## Phase 3: Instruction governance

1. Add explicit inheritance/override semantics: global(agent) → channel → thread.
2. Add service endpoints for AI-assisted instruction edits (default first, then OpenClaw).
3. Add instruction audit metadata (who changed, when, scope, before/after diff summary).

# Acceptance Criteria

1. Without any OpenClaw node configured, users can still use default chat and routing resolves to a stable default-node identity.
2. Channel and thread instructions continue to save/read and apply correctly under default routing.
3. Default appears as a built-in node in routing UI without adding install/import steps.
4. OpenClaw routing behavior and plugin flows do not regress.
5. Chat message metadata exposes unified target fields across default/OpenClaw (`targetNodeId/targetNodeName`).

# Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/mobile_chat_app && flutter test`
- `cd apps/mobile_chat_app && flutter analyze`
