# Agent Loop Limit Empty Final

## Background

A production task reached the internal tool-call budget and persisted an empty completed assistant message. The database showed tool-call rows were present, but the final assistant message had `content_len = 0`. This is more likely a program-level loop termination case than a model intentionally replying with empty text.

## Goals

- Increase the default model-driven agent-loop budget to 10 steps and 50 tool calls.
- Never persist an empty completed assistant response after tool calls.
- Make budget termination visible to users with a clear explanation that the internal step or tool-call limit was reached.
- Preserve metadata that explains the stop reason for future debugging.

## Implementation Plan

1. Raise default loop limits in `apps/node_backend/src/routes/chat.ts`.
2. Track completed/failed tool calls while processing the agent loop.
3. Before final assistant upsert, convert an empty post-tool final response into a visible failed assistant message with a specific limit reason.
4. Add backend route tests for default limits and empty post-tool final handling.
5. Update code maps for the agent-loop limit behavior.

## Acceptance Criteria

- Default respond requests pass `maxSteps: 10` and `maxToolCalls: 50` to the agent loop.
- If tool calls occurred and no final text is produced, the persisted assistant message has non-empty explanatory content.
- If the tool-call or step limit was reached, the message says which internal limit was reached.
- Tests cover the regression that previously wrote an empty completed assistant message.

## Validation Commands

- `cd apps/node_backend && npm test -- src/routes/chat.test.ts`
- `cd apps/node_backend && npm run type-check`
