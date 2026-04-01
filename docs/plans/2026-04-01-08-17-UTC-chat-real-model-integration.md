# Background
The current chat flow in `agent_core` returns a local stub response (`(agent_core stub) Received: ...`) instead of invoking a real LLM provider. This blocks end-to-end conversational behavior in the app.

# Goals
- Replace the stub path in `AgentSessionImpl` with real provider HTTP calls.
- Support current configured providers (`anthropic`, `gemini`) with model selection from `AgentSettings`.
- Preserve existing `AgentSessionEvent` behavior (`TextDeltaEvent`, `MessageCompleteEvent`, `AgentErrorEvent`, `RunCompleteEvent`).
- Keep tests passing and add coverage for provider/error handling.

# Implementation Plan (phased)
1. Add a small provider gateway inside `agent_core` that maps `AgentSettings.provider` to real HTTP APIs.
2. Read provider credentials and endpoints from environment (`String.fromEnvironment`) and fail fast with actionable errors when missing.
3. Update `AgentSessionImpl` to call the gateway and emit deltas + completion text from provider output.
4. Add unit tests for:
   - successful provider response mapping
   - unsupported provider handling
   - missing credentials handling
5. Run project bootstrap and package tests (`./tools/init_dev_env.sh`, `melos exec --scope=agent_core -- dart test`).

# Acceptance Criteria
- Sending a message through `AgentSessionImpl` attempts a real LLM API call for supported providers instead of echoing the stub text.
- On success, exactly one `MessageCompleteEvent` is emitted with model output text.
- On configuration/provider failures, `AgentErrorEvent` is emitted with useful diagnostic text.
- `RunCompleteEvent` is always emitted and session lifecycle semantics remain unchanged.
- `melos exec --scope=agent_core -- dart test` passes.
