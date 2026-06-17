# Background

The request moved from planning to coding: implement built-in agent/node semantics for the default router, not only documentation.

# Goals

1. Introduce a stable built-in node identity for default router on backend.
2. Emit unified route-target metadata in `/api/chat/respond` for default and OpenClaw.
3. Validate no regression through focused backend tests.

# Implementation Plan (phased)

## Phase 1
- Add built-in default node constants and helper in `chatRouterService`.

## Phase 2
- Unify metadata output in chat respond path:
  - `targetNodeId`
  - `targetNodeName`
  - `targetSourcePlatform`
  - `resolvedRouteKind`

## Phase 3
- Update and pass related Vitest suites:
  - `src/routes/chat.test.ts`
  - `src/services/chatRouterService.test.ts`

# Acceptance Criteria

1. Default route writes stable `node_builtin_default` metadata.
2. OpenClaw route continues to write real node metadata.
3. Related tests pass.

# Validation Commands

- `cd apps/node_backend && npm test -- --run src/routes/chat.test.ts src/services/chatRouterService.test.ts`
