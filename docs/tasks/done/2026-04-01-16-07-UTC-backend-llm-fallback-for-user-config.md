# Background
Users still hit `Missing BRICKS_GEMINI_API_KEY` in chat because direct provider calls depend on process-level environment keys, while user-specific keys are stored in backend configs.

# Goals
- Allow chat sessions to run through backend user-configured LLM settings when available.
- Remove hard dependency on frontend process environment API keys for normal authenticated chat usage.
- Support session-scoped `configId` + `model` overrides without persisting session state.

# Implementation Plan (phased)
1. Extend `AgentSettings` with optional backend routing fields (`apiBaseUrl`, `authToken`, `configId`).
2. Add backend chat path in `RealModelGateway` that calls `/api/llm/chat` with auth and optional provider/model/config override.
3. Update mobile chat screen to populate backend routing fields (base URL, token, selected config slot).
4. Update Node backend `/api/llm/chat` + LLM service to accept optional `configId` and resolve runtime config by ID first.
5. Run analyze and tests for affected packages/apps.

# Acceptance Criteria
- Authenticated chat can succeed without `BRICKS_GEMINI_API_KEY` set in frontend runtime.
- Session model/config overrides are forwarded to backend and do not mutate default config.
- Existing app/package checks pass.
