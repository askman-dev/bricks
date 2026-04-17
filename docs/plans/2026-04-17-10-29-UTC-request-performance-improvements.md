# Request performance improvements

## Problem

The current Bricks request model favors simple polling over request efficiency.
That works for correctness, but it can create too many empty requests and raise
the chance of `429` responses when either:

- the web client repeatedly polls `/api/chat/sync/:sessionId`
- the OpenClaw plugin repeatedly polls `/api/v1/platform/events`

We do **not** want to implement the full fix in this task. This document is a
future-work guide for improving request efficiency safely.

## Current state

### Web chat sync

- `apps/mobile_chat_app/lib/features/chat/chat_screen.dart`
- The chat UI polls `/api/chat/sync/:sessionId` every 2 seconds when the active
  scope is routed to OpenClaw or when there are pending assistant tasks.
- The current loop is timer-driven, not completion-driven.
- Recent work already reduced one source of 429s by moving `/api/chat/sync/*`
  off the coarse global `/api/*` limiter.

### OpenClaw plugin polling

- `apps/node_openclaw_plugin/src/pluginRunner.ts`
- The plugin loop is already **end-to-start**:
  1. run a full tick
  2. pull events
  3. ack them
  4. write message updates
  5. then sleep
- Default poll interval is 2000 ms.

### Backend rate limiting

- `apps/node_backend/src/app.ts`
- A coarse limiter still applies to most `/api/*` traffic:
  - 100 requests / 15 minutes / IP
- That is too small for any route that intentionally polls.
- `/api/chat/sync/*` has already been carved out, but `/api/v1/platform/*`
  still deserves its own dedicated policy.

### Platform routes

- `apps/node_backend/src/routes/platform.ts`
- Platform routes already have authentication and scope checks, but they do not
  yet have a platform-specific limiter or a long-poll contract.

## Goals

1. Reduce empty requests.
2. Reduce `429` responses during normal chat/plugin operation.
3. Keep perceived latency low when new messages arrive.
4. Stay compatible with Vercel/serverless constraints.
5. Avoid broad protocol changes until the smaller fixes are validated.

## Recommended staged plan

### Stage 1: Improve polling behavior without changing the HTTP contract

#### Web `/api/chat/sync`

Move the web client to **completion-based polling**:

- schedule the next sync **after** the previous request finishes
- do not use fixed periodic ticks as the source of truth

Add client backoff on failed syncs:

- success: `2s`
- first failure: `4s`
- second failure: `8s`
- later failures: cap at `10s`

Reset the delay back to `2s` after any successful response.

Also:

- honor `Retry-After` if the backend sends it
- add a small jitter window (for example ±10%) so many clients do not poll in
  lockstep
- make sure only one sync loop is active per visible scope/tab

#### OpenClaw plugin `/api/v1/platform/events`

The plugin already polls end-to-start, so it is in a better shape than the web
client. The next improvement should be **retry behavior**, not loop shape:

- treat `429` and retryable `5xx` responses as backoff signals
- use the same capped retry ladder:
  - `2s` -> `4s` -> `8s` -> `10s`
- prefer backend-provided `Retry-After` when present

### Stage 2: Add route-specific backend rate limiting

#### `/api/chat/sync/*`

Keep the current approach:

- do **not** let this route share the generic `/api/*` IP limiter
- keep a route-specific budget keyed by authenticated chat context

#### `/api/v1/platform/*`

Add a dedicated limiter for platform traffic instead of sharing the generic IP
bucket.

Recommended keying:

- JWT platform token mode: `pluginId:userId`
- static platform key mode: `pluginId:remoteAddress` (or another stable plugin
  identity if one is introduced later)

Recommended behavior:

- separate read-heavy polling routes from write routes if needed
- return structured `429` errors with retry hints
- avoid adding many new environment variables unless real operations require it

### Stage 3: Reduce empty responses with long polling

If Stage 1 and Stage 2 are still not enough, add **short long-poll** behavior.

#### `/api/chat/sync/:sessionId`

Allow the server to hold an empty request for up to **10 seconds** before
returning a no-change response.

Behavior:

- if new messages already exist, return immediately
- if no new messages exist, wait up to 10 seconds
- return early as soon as new data becomes available
- return an empty/no-change payload only when the wait window expires

#### `/api/v1/platform/events`

Apply the same idea to platform event pulls:

- return immediately when unread events exist
- otherwise hold the request briefly instead of replying empty right away

Important note:

- this is a bigger change than client backoff
- validate carefully on Vercel/serverless before rolling it out broadly

### Stage 4: Consider event-driven transport only if needed

If polling and long-polling are still not sufficient, then evaluate:

- Server-Sent Events for chat updates
- Server-Sent Events for platform events
- WebSockets only if truly bidirectional low-latency behavior is needed

This should come later because it increases operational and protocol
complexity.

## Detailed implementation notes

### Web sync scheduler

Recommended behavior for the next implementation:

1. start one sync request
2. wait for completion
3. decide the next delay from the outcome
4. schedule exactly one future sync

Outcome table:

| Outcome | Next delay |
| --- | --- |
| Success | 2s |
| Retryable failure / 429 | 4s, then 8s, then 10s max |
| `Retry-After` present | use `Retry-After`, capped at a sane upper bound if desired |

Additional safeguards:

- ignore stale responses when the user changed channel/thread while the request
  was in flight
- cancel timers immediately on scope switch
- consider pausing or widening intervals when the tab is hidden

### Platform polling

The plugin loop should remain:

```text
tick -> sleep
```

That is already the right shape.

Future work should focus on:

- backend rate-limit symmetry
- retry/backoff
- optional long-poll for empty event pulls

## Validation plan

### Functional tests

- web sync scheduler never runs more than one request at a time
- failure backoff caps at `10s`
- success resets delay to `2s`
- stale scope changes do not reschedule old loops
- platform limiter does not block normal polling traffic

### Load / soak checks

- one OpenClaw-routed web tab open for 15+ minutes
- multiple tabs for the same user
- multiple plugin runners against the same backend
- empty queue behavior vs active queue behavior

### Metrics to watch

- requests/minute per active session
- requests/minute per active plugin
- `429` count by route
- empty response ratio
- median and p95 latency
- Vercel execution time and timeout behavior for long-poll candidates

## Recommended implementation order

1. Web completion-based polling with `2s -> 4s -> 8s -> 10s` capped backoff
2. Platform route-specific limiter and plugin retry/backoff
3. Short long-poll prototype for `/api/chat/sync`
4. Long-poll evaluation for `/api/v1/platform/events`
5. Event-driven transport only if polling remains insufficient

## Decision log

- This document intentionally records future work only.
- We are **not** implementing the long-poll / advanced performance changes in
  this task.
- Prefer fixed code-level defaults first; only introduce more env config if
  production operations actually need it.
