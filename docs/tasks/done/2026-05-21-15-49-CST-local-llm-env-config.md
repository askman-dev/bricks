# Local LLM Env Config

## Background

Manual local testing should not require writing a local provider key into the
cloud `api_configs` table. The backend currently resolves LLM runtime config
only from user database rows, which makes local model testing risky when the
selected database is shared with a real user.

## Goals

- Add an explicit dev/test-only environment fallback for LLM runtime config.
- Keep production behavior unchanged unless the fallback is explicitly enabled.
- Ignore the fallback in production even if the local env variables are
  accidentally present.
- Support the current `.env.local` Gemini variables without writing to Turso.
- Cover provider/model/endpoint/key resolution with backend unit tests.

## Implementation Plan

1. Add a `LOCAL_LLM_CONFIG_ENABLED=true` gate in `llm_service.ts` plus a
   local/dev runtime guard.
2. Resolve local config from generic `LOCAL_LLM_*` variables, with Gemini
   aliases for existing local usage.
3. Prefer the local env config before database configs only when enabled.
4. Export a small test-only resolver wrapper and add `llm_service.test.ts`.
5. Update local manual testing docs to use env fallback instead of creating a
   fixture-user database config.

## Acceptance Criteria

- Without `LOCAL_LLM_CONFIG_ENABLED=true`, LLM config still comes from
  `api_configs`.
- In production, LLM config still comes from `api_configs` even if
  `LOCAL_LLM_CONFIG_ENABLED=true` is accidentally set.
- With `LOCAL_LLM_CONFIG_ENABLED=true` and `GEMINI_API_KEY`, runtime config uses
  the env key/model only when the backend is running in an explicit local/dev
  mode and does not need database rows.
- Invalid local endpoints still fail endpoint validation.
- Local manual testing docs no longer recommend writing provider keys to cloud
  Turso as the default path.

## Validation Commands

- `cd apps/node_backend && npm test -- src/llm/llm_service.test.ts`
- `cd apps/node_backend && npm run type-check`
