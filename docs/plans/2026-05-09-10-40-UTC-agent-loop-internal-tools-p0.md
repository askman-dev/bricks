# Background

Bricks chat backend currently supports async message transport with SSE synchronization and local/plugin routing. We need to start implementing an internal-tool-first agent loop for local routing, while keeping database changes minimal and reusing existing chat task/message persistence.

# Goals

1. Introduce a local agent loop service entrypoint for `/api/chat/respond` local route.
2. Define P0 internal tool names:
   - `chat.channel.instruction.set`
   - `chat.thread.instruction.set`
   - `chat.channel.create`
   - `chat.thread.create`
3. Implement instruction tools using existing scope-setting persistence.
4. Keep unsupported tools explicit and structured (not silently ignored).
5. Avoid DB schema changes in this phase.

# Implementation Plan (phased)

## Phase 1: Add agent-loop service skeleton
- Add a dedicated service module that defines:
  - loop result/status contract
  - supported tool constants
  - tool execution results
- Keep this module independent from route handler internals.

## Phase 2: Implement internal tool execution
- Implement `chat.channel.instruction.set` and `chat.thread.instruction.set` by calling `upsertChatScopeSetting`.
- Return deterministic structured results for all tools.
- Mark `chat.channel.create` and `chat.thread.create` as not yet implemented with a stable error code.

## Phase 3: Integrate local respond path
- Wire local `/api/chat/respond` flow to call the new service before the existing model streaming branch.
- Preserve current async transport behavior and SSE visibility.

## Phase 4: Add focused tests
- Add unit tests for tool dispatch and unsupported-tool behavior.

# Acceptance Criteria

1. The codebase contains a local agent-loop service with stable contracts and tool names.
2. Two instruction tools persist settings through existing scope-setting service.
3. Unsupported tools return structured `not_implemented` errors.
4. Existing local respond behavior remains functional.
5. No database migration is introduced.

# Execution Checklist (live status)

- [x] Added internal tool constants and allowlist service entrypoint.
- [x] Implemented instruction tools:
  - `chat.channel.instruction.set`
  - `chat.thread.instruction.set`
- [x] Implemented scope-creation tools:
  - `chat.channel.create`
  - `chat.thread.create`
- [x] Added bounded internal tool sequence execution (`executeInternalToolSequence`) with stop-on-failure behavior.
- [x] Integrated local `/api/chat/respond` branch with explicit internal tool payload execution.
- [x] Added inferred internal tool calls from slash-like user commands.
- [x] Added route/service tests for explicit and inferred tool execution branches.
- [x] Replace request-driven tool execution with model-driven multi-step think→call→observe→final loop controller. (`buildAgentTools` + `streamWithAgentToolsAndUserConfig` with AI SDK `streamText` tools + `maxSteps`)
- [x] Add first-class loop controls (`maxSteps`, `maxToolCalls`, `timeout`) to route-level configuration and response metadata.
- [x] Add step-by-step assistant message updates for each loop phase (not only summary message) to maximize SSE observability. (`onStepFinish` writes per-step tool-call messages with `${assistantMessageId}:ts:N` ids)
