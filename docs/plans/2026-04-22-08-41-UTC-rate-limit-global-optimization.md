# Background

The backend currently applies a coarse global limiter to all `/api/*` routes (`100 requests / 15 minutes / IP`). This can over-throttle authenticated traffic such as `GET /api/config?category=llm`, especially when upstream gateway rate limiting already exists. Chat and platform routes also maintain route-specific limiters, creating mixed and hard-to-reason behavior.

# Goals

1. Remove the global `/api/*` limiter.
2. Keep `GET /api/config` without app-layer limiting (rely on gateway).
3. Add config write limiter: `60 requests / minute / user`.
4. Add anonymous auth limiter: `20~30 requests / minute / IP` (implement as `30/min/IP` initial policy).
5. Unify chat and platform route-level limits to `120 requests / minute` to simplify policy while protecting DB from high-frequency bursts.

# Implementation Plan (phased)

## Phase 1: App-level routing and limiter wiring
- Remove global limiter middleware from `apps/node_backend/src/app.ts`.
- Add dedicated auth limiter middleware mounted on auth routes only.
- Keep existing routing structure (`/api/auth` and `/api` mounts for auth router).

## Phase 2: Config route limiter
- In `apps/node_backend/src/routes/config.ts`, introduce a write limiter applied only to `POST/PUT/PATCH/DELETE` handlers.
- Key by authenticated `userId` (fallback to IP if absent for safety).
- Leave `GET /api/config` unthrottled at app layer.

## Phase 3: Chat + platform policy unification
- Update chat constants so sync/respond/events all use `120 requests/minute`.
- Update platform defaults so read/write/events-stream all use `120 requests/minute`.
- Keep keying strategies unchanged (chat: user+session, platform: plugin+user/IP).

## Phase 4: Test updates and verification
- Update tests that assumed global limiter behavior.
- Add/adjust tests to validate:
  - config GET not blocked by app limiter.
  - config writes are limited per-user.
  - auth endpoints are rate limited by IP.
  - chat/platform still enforce route-level 429 behavior with unified policy defaults.

## Phase 5: Code map sync
- Review and update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` for policy/index changes related to backend auth and backend chat/platform behavior.

# Acceptance Criteria

1. Repeated requests to `/api/config?category=llm` no longer receive the prior global-IP 429 from app-layer limiter under normal authenticated usage.
2. `POST/PUT/DELETE /api/config*` are limited to `60/min/user`.
3. Auth anonymous endpoints are limited to `30/min/IP`.
4. Chat and platform default route limits are each `120/min` across their route-specific limiters.
5. Node backend unit tests pass for updated limiter behavior.
