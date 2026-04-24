# OpenClaw agents capture and display

## Background

The task target is to capture agents available inside OpenClaw and surface them in
the Bricks chat interaction so users can reference them during conversation.

This work must be isolated in a dedicated local worktree to avoid interfering with
other active task worktrees.

## Goals

- Work from the dedicated worktree at `.worktree/openclaw-agents-capture-display`.
- Identify where OpenClaw internal agent metadata can be observed or queried.
- Add a reliable path to persist or expose those agents to the mobile chat app.
- Display the captured agents in the conversation UI in a way users can reference.
- Keep code maps updated if feature entries, business logic, tests, or docs change.

## Implementation Plan (phased)

### Phase 1: Requirements intake

Wait for the detailed product and technical requirements, including expected agent
identity fields, source of truth, refresh behavior, and UI interaction model.

### Phase 2: Current-flow mapping

Inspect the OpenClaw plugin, backend platform routes, chat routing logic, and mobile
chat UI to map where agent information should enter and where it should be rendered.

Findings:

- The mobile composer already has a route-bound `@` menu.
- The OpenClaw route currently shows a disabled placeholder item in that menu.
- Platform node tokens already bind `userId + pluginId`, and the backend can map
  that plugin ID back to a node.
- There is not yet a selected-node router state in this branch, so this change uses
  the first/default platform node while keeping the API nodeId-scoped for future
  selected-node routing integration.

### Phase 3: Data contract

Define or reuse a stable agent data contract that separates display naming from
storage identity. Include any required IDs, labels, source platform metadata, and
reference syntax.

### Phase 4: Implementation

Implement the smallest end-to-end path that captures OpenClaw agents and makes them
available in the chat interaction. Keep existing selected-node-routing worktree
changes isolated.

Implemented path:

1. Add config `GET /api/config/nodes/:nodeId/agents` for the authenticated mobile
   app to read agents for the matching node.
2. For `sourcePlatform=openclaw`, resolve agents on demand via
   `openclaw agents list --json` instead of backend persistence.
3. Replace the OpenClaw route `@` placeholder with reported agents and insert an
   `@agentId` reference into the composer when selected.

### Phase 5: Validation

Run targeted tests from the relevant package directories. For mobile app Flutter
checks, run commands from `apps/mobile_chat_app` as required by `AGENTS.md`.

## Acceptance Criteria

- The task uses `.worktree/openclaw-agents-capture-display` and does not modify
  other active worktrees.
- OpenClaw agents are captured from the agreed source of truth.
- Users can see and reference captured OpenClaw agents from the conversation
  interaction.
- Agent display labels and stable storage IDs are kept separate.
- Existing OpenClaw routing and chat behavior continue to pass targeted tests.
- Code maps are updated if the implementation changes feature entries, logic
  indexes, tests, or documentation indexes.
