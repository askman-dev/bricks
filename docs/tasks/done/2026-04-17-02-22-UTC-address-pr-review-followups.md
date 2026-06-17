## Background
Recent PR review comments identified contract drift between the OpenClaw integration document and current backend implementation, plus two code issues: insufficient JWT plugin isolation in platform auth middleware and plugin-side event filtering that drops valid user messages.

## Goals
1. Align integration documentation to the currently implemented API/auth behavior.
2. Enforce strict plugin isolation for JWT platform tokens.
3. Ensure plugin event filtering does not skip valid user-origin events.
4. Keep related tests and code maps synchronized.

## Implementation Plan (phased)
- [x] Inspect review comments, current backend/plugin implementation, and impacted docs/tests.
- [x] Update integration doc sections for auth model, PATCH contract shape, rawId examples, and current implementation alignment.
- [x] Tighten platform JWT validation to require pluginId claim and header equality.
- [x] Adjust OpenClaw plugin event filter to avoid dropping same-user message.created events.
- [x] Update/add targeted backend and plugin tests for new auth/filtering behavior.
- [x] Run targeted tests and finalize.

## Acceptance Criteria
- Integration doc reflects current supported auth modes (JWT primary + optional static key fallback) and current MVP message patch contract.
- Middleware rejects platform JWT tokens missing pluginId claim, and still rejects pluginId mismatches.
- Plugin processes message.created events from user senders even when sender.userId equals token userId, while still ignoring assistant/system events.
- Targeted tests pass in `apps/node_backend` and `apps/node_openclaw_plugin`.
