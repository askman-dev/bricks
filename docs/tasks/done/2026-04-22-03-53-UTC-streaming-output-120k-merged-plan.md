# Streaming Output 120K Boundary + User-side Incremental Delivery (Merged Plan)

## Background
The previous plan audited route-level streaming capability and added conservative output limits. Based on follow-up requirements, we now need to merge that planning context with a concrete implementation plan that:
1) raises output boundaries to 120K as the new default budget, and
2) achieves true user-visible incremental output for the default chat router, while preserving the existing `/respond` acceptance flow and SSE architecture.

This merged plan supersedes and consolidates prior route-audit planning for the same objective.

## Goals
1. Set output budget defaults and upper bounds to **120K** for model output controls.
2. Keep `/api/chat/respond` request/ack contract unchanged.
3. Keep existing SSE transport shape (`/api/chat/events/:sessionId`) unchanged.
4. Refactor backend default-router generation to stream from the model and persist incremental assistant content so users can see progressive updates via existing SSE polling.
5. Align route docs with the final behavior and boundaries.

## Implementation Plan (phased)
1. **Boundary normalization to 120K**
   - Update LLM route `maxTokens` defaults and upper-bound validation to 120K.
   - Update platform message text cap to 120K characters.
2. **Default router true incremental generation**
   - Replace single-shot model generation in chat default async pipeline with streaming model generation.
   - Persist assistant message progressively (same messageId, growing content, `dispatched` state during stream).
   - Finalize the same message with `completed` state after stream ends; preserve failure write-path semantics.
3. **Test adaptation**
   - Update route tests for the new 120K thresholds.
   - Add assertions that default-router async flow now emits intermediate `dispatched` writes before completion.
4. **Documentation merge**
   - Refresh audit/report docs so boundaries and streaming behavior match implementation.

## Acceptance Criteria
- `POST /api/llm/chat` and `POST /api/llm/chat/stream` enforce 120K default and 120K upper-bound for `maxTokens`.
- `POST /api/chat/respond` validates and propagates 120K-bounded `maxTokens` into default async generation.
- Default router uses model streaming and writes incremental assistant content updates observable through existing `/api/chat/events/:sessionId` flow.
- `POST /api/v1/platform/messages` and `PATCH /api/v1/platform/messages/:messageId` reject payload text beyond 120K.
- Updated route tests pass for changed behavior and thresholds.
