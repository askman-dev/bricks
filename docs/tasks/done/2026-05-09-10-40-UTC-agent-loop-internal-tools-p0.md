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
- Implement `chat.channel.create` and `chat.thread.create` using `upsertChatScopeSetting` with `scopeType` set appropriately.
- Return deterministic structured results for all tools.

## Phase 3: Integrate local respond path
- Wire local `/api/chat/respond` to use a model-driven agent loop (`streamWithAgentToolsAndUserConfig`) for slash commands, exposing tools defined in `buildAgentTools`.
- Normal (non-slash) messages use the existing `streamWithUserConfig` path for incremental streaming.
- Preserve current async transport behavior and SSE visibility.

**Note:** `executeInternalToolSequence` and `inferInternalToolCallsFromMessage` are exported from the service but are **not** currently called by the route. The route instead delegates tool selection and execution to the model via `buildAgentTools` / `streamText`. These functions remain available for future explicit or server-side-inferred tool dispatch.

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
- [x] Added bounded internal tool sequence execution (`executeInternalToolSequence`) with stop-on-failure behavior. *(exported from service; not currently called by route — reserved for future server-side dispatch)*
- [x] Added inferred internal tool calls from slash-like user commands (`inferInternalToolCallsFromMessage`). *(exported from service; not currently called by route — reserved for future use)*
- [x] Added route/service tests for tool execution, inference, and argument validation.
- [x] Replaced request-driven tool execution with model-driven multi-step think→call→observe→final loop controller. (`buildAgentTools` + `streamWithAgentToolsAndUserConfig` with AI SDK `streamText` tools + `maxSteps`)
- [x] Gated agent tool exposure to slash-command requests only, preventing unintended tool calls during ordinary conversation.
- [x] Add first-class loop controls (`maxSteps`, `maxToolCalls`, `timeout`) to route-level configuration and response metadata.
- [x] Add step-by-step assistant message updates for each loop phase (not only summary message) to maximize SSE observability. (`onStepFinish` writes per-step tool-call messages with bounded `stepMessageId` ≤ 255 chars)
