# Agent Loop Real Stop Reason

## Background

The chat agent can complete tool calls and then persist an empty failed assistant response when no final text is produced. A recent production example proved that the failure was not caused by the tool-call limit or step limit, but the stored metadata did not contain enough raw stop information to prove whether the stream timed out, errored, or ended normally with no final text.

## Goals

- Increase the per-step agent loop timeout from 15 seconds to 60 seconds.
- Record timeout only when the stream was actually aborted by the timeout path.
- Preserve distinct stop reasons for tool-call limit, step limit, stream errors, SDK finish metadata, and generic empty final responses.
- Keep the timeout scoped to a single model step, while total work remains bounded by max steps and max tool calls.

## Implementation Plan

1. Add stream stop metadata to the agent-loop LLM streaming wrapper.
2. Reset the timeout after each completed model step instead of using one whole-loop wall clock.
3. Classify empty post-tool final responses from real stop metadata in the chat route.
4. Add route tests for default timeout configuration and timeout-specific empty-final failure metadata.

## Acceptance Criteria

- Default agent-loop requests use `timeoutMs: 60000`.
- A true timeout persists `agentLoopStopReason.type = "timeout_reached"` with `timeoutMs` and `timeoutStepIndex`.
- Tool-call and step limits continue to persist their own stop reason types.
- Empty final responses without timeout or explicit limits remain `empty_final_after_tool_calls`.
- Backend route tests and type checks pass.

## Validation Commands

- `cd apps/node_backend && npm test -- src/routes/chat.test.ts`
- `cd apps/node_backend && npm run type-check`
