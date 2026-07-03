# Auth Limiter Scope

## Background

The preview app returned `Too many anonymous auth requests from this IP` for an authenticated `GET /api/config?category=llm` request. The request carried an Authorization bearer token, so the failure was not an anonymous user state.

## Goals

- Keep anonymous OAuth rate limiting for GitHub login start/callback routes.
- Prevent the legacy `/api` auth mount from applying the anonymous auth limiter to later API routes such as `/api/config`.
- Add regression coverage for the production route mounting order.

## Implementation Plan

1. Scope `anonymousAuthLimiter` to OAuth anonymous endpoints only.
2. Add an auth route integration test that mounts `authRoutes` at `/api` before a config route and repeatedly reads config.
3. Update code maps for the auth limiter routing risk.

## Acceptance Criteria

- Authenticated `GET /api/config?category=llm` is not blocked by anonymous auth rate limiting.
- OAuth start/callback routes still keep the anonymous auth limiter.
- Focused backend route tests pass.

## Validation Commands

- `cd apps/node_backend && npm test -- --run src/routes/auth.test.ts src/routes/config.test.ts`
