# Streaming Route Boundary Audit and Output-Length Limits

## Background
The backend exposes multiple chat/platform routes with mixed delivery modes (request/response, polling sync, and SSE). We need to verify route-by-route whether users can observe dynamic incremental output and add explicit output-length boundaries to avoid unbounded payload growth.

## Goals
1. Audit each relevant route and classify dynamic push capability (true streaming vs batch/poll semantics).
2. Add enforceable output-length limits for AI/plugin-generated textual output paths.
3. Document route-level boundary behavior and known constraints for future tuning.

## Implementation Plan (phased)
1. **Route audit**
   - Inspect `apps/node_backend/src/routes/*.ts` plus related services to map all output-producing endpoints.
   - Identify whether each route supports incremental updates to clients (SSE chunking, SSE poll loop, or no dynamic push).
2. **Boundary implementation**
   - Add shared output boundary constants in backend routes.
   - Enforce max output tokens upper-bound for `/api/llm/chat` and `/api/llm/chat/stream` requests.
   - Enforce max text length for platform message create/patch write paths.
   - Ensure default chat router async model call honors validated `maxTokens`.
3. **Validation and report**
   - Run node backend test suite sections related to modified routes.
   - Write an audit report summarizing each route’s dynamic push capability and boundary limits.

## Acceptance Criteria
- Every relevant chat/platform output route is classified in a written audit table.
- LLM endpoints reject invalid/oversized `maxTokens` and cap upper bound deterministically.
- Platform message write endpoints reject oversized text payloads with clear 400 errors.
- Tests covering modified route behavior pass.
