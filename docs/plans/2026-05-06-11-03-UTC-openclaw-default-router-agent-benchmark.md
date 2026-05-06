# Background

You requested that before upgrading Bricks default router into an agent-equivalent node architecture, we should first study OpenClaw (especially OpenClaw + Discord) in depth, including technology choices, architecture, and prompt design, then produce an implementation-ready plan.

Based on repository/documentation research of `openclaw/openclaw`, this document converts benchmark findings into a practical Bricks migration blueprint.

# Goals

1. Extract key OpenClaw mechanisms for control plane, session routing, agent identity, and prompt assembly.
2. Map those findings to current Bricks gaps and define what default router must gain.
3. Produce a phased implementation plan for built-in default-node semantics and AI-governed channel/thread instructions.

# OpenClaw Findings (fact extraction)

## 1) Technology choices (control plane + channel plugins)

- OpenClaw uses a **single long-lived Gateway daemon + typed WebSocket protocol** as a unified control plane.
- All messaging surfaces (including Discord) attach to the Gateway; clients and nodes connect through the same WS surface, separated by role/capability.
- Discord integration follows official gateway + bot token + account-aware config and behaves as a channel plugin surface.

Implication for Bricks: default router should not remain an `if/else` branch; it should be a first-class routing target inside the control-plane model.

## 2) Architecture (routing as a first-class object)

- OpenClaw is driven by **session route metadata + stable agent identity**, not raw provider passthrough.
- Different channels (Discord/Telegram/etc.) converge on consistent `agent:<agentId>:...` semantics.
- Channel ingress and agent execution are decoupled but composable.

Implication for Bricks:

- default router needs stable built-in `nodeId/agentId` included in resolved routing.
- scope settings should return resolved target semantics, not only a router string.

## 3) Prompt design (OpenClaw-owned prompt assembly)

- OpenClaw uses a **platform-owned system prompt assembly** model, not transparent passthrough.
- Prompt sections are structured with cache-stable prefixes and runtime-dynamic suffixes.
- Workspace bootstrap files (`AGENTS.md`, `SOUL.md`, `TOOLS.md`, etc.) are injected context; sub-agents use smaller prompt modes.

Implication for Bricks:

- default router agentization should move to layered prompt assembly:
  - agent layer (default built-in)
  - channel layer
  - thread layer
- explicit governance is required: inheritance, override, truncation, audit.

## 4) Why OpenClaw + Discord feels “agent-native”

- Discord is only the ingress/egress surface; the durable layer is agent/session routing inside Gateway.
- What users perceive as editable instructions, continuity, and cross-channel consistency comes from the unified agent abstraction.

Implication for Bricks:

- the correct target is “default router as built-in agent node,” not “default emulating a plugin.”

# Implementation Plan (phased)

## Phase 1: Default-router node identity (Backend first)

1. Introduce built-in default node constants:
   - `nodeId: node_builtin_default`
   - `sourcePlatform: builtin`
   - `displayName: Bricks Default`
2. Extend resolved routing output:
   - `router`, `nodeId`, `nodeKind`, `agentName`, `sourcePlatform`
3. In `/api/chat/respond`, emit unified metadata for both default/openclaw:
   - `targetNodeId`, `targetNodeName`, `targetPluginId?`, `resolvedRouteKind`

## Phase 2: Scope setting + UI alignment

1. Add `resolvedNodeId/resolvedNodeName` to scope-setting query responses.
2. Show default as a built-in node in router menus (no install, read-only).
3. For thread-follow-channel mode, return resolved target semantics to avoid ambiguous inheritance.

## Phase 3: Prompt assembly + instruction governance

1. Build a layered prompt assembler:
   - base system
   - built-in agent instructions
   - channel instructions
   - thread instructions
2. Add AI instruction-edit service paths (default first, OpenClaw later).
3. Add instruction audit fields: `changedBy`, `changedAt`, `scope`, `diffSummary`.

## Phase 4: OpenClaw interoperability boundaries

1. Keep built-in default node independent of plugin lifecycle.
2. Keep OpenClaw node behavior on existing plugin path.
3. Standardize observability fields for mixed-router troubleshooting.

# Acceptance Criteria

1. With no OpenClaw nodes configured, default remains usable with stable node identity.
2. Channel/thread instructions inherit/override correctly under default and participate in prompt assembly.
3. UI shows default as built-in node with no import/install workflow.
4. OpenClaw async placeholder/backfill path remains unchanged.
5. In mixed routing (default ↔ openclaw), metadata fields remain consistently observable.

# Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/mobile_chat_app && flutter test`
- `cd apps/mobile_chat_app && flutter analyze`
