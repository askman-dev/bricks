# Agent Loop Empty Final Root Cause Note

## Background

During local manual testing, the message `我有哪些 todo` in
`task-1779354793673-0` showed a failed assistant response:

`The assistant completed tool calls but did not produce a final answer. Please retry or narrow the request.`

This note records the confirmed facts and the remaining uncertainty before
changing timeout or stop-reason behavior.

## Confirmed Facts

- The task id was `task-1779354793673-0`.
- The user message was written at `2026-05-21T17:13:13.673`.
- The final assistant message was later updated to `task_state = failed`.
- The final metadata had:
  - `agentLoopStopReason.type = empty_final_after_tool_calls`
  - `toolCallCount = 2`
  - `completedToolCallCount = 2`
  - `failedToolCallCount = 0`
  - `maxToolCalls = 10`
  - `stepCount = 1`
  - `maxSteps = 10`
- Therefore this incident was not caused by the tool-call limit.
- Therefore this incident was not caused by the step limit.
- Both tool calls were `todo_list`.
- Both tool calls returned successful todo data.
- No provider raw finish reason, abort event, or final-step error was persisted for this task.

## Root Cause Statement

The confirmed root cause is:

The backend completed successful tool calls, but the agent loop ended before a
tool-free final answer was persisted. The current code then converted that state
into `empty_final_after_tool_calls`.

## Important Uncertainty

We cannot prove from the current database records that the model itself
intentionally returned an empty final answer. The system did not persist enough
provider/SDK finish metadata to distinguish:

- the provider returned a tool step and then stopped without final text
- the SDK ended the loop after tool results without another text step
- the AbortController timeout interrupted the loop before final text
- another stream finish/error condition occurred but was not recorded

The timing makes timeout plausible, because the default loop timeout was 15s and
the task duration was close to that range, but timeout is not proven by the
persisted metadata.

## Required Fix Direction

- Do not label all empty post-tool finals as timeout.
- Persist the real stop reason when the SDK/provider exposes it.
- If timeout fires, persist a specific `timeout_reached` stop reason.
- Keep tool-call limit and step limit as separate stop reasons.
- Prefer per-step/model-call timeout semantics instead of one wall-clock timeout
  for the whole multi-step tool loop.
- Increase the default timeout from 15s to a safer value such as 60s only as a
  mitigation, not as the root-cause proof.

## Acceptance Criteria

- Empty final after tools must include a precise persisted stop reason when one
  is known.
- Unknown stop reasons must remain marked as unknown/empty-final, not rewritten
  as timeout.
- Future investigations can tell whether an incident was caused by timeout,
  tool-call limit, step limit, provider finish, or an unclassified empty final.
