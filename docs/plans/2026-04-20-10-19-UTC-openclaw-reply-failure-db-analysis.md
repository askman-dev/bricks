# OpenClaw reply failure DB analysis

## Problem

The current async OpenClaw flow can persist a delayed assistant reply, but the
database model does not express the reply relationship explicitly. Core async
workflow state is also encoded in message metadata (`pendingAssistantMessageId`)
and exported with a text search, which is brittle.

## Proposed approach

Keep `chat_messages` as the source of truth for visible conversation history and
preserve `write_seq` ordering for late replies. Normalize the async reply
contract into first-class columns so the backend and plugin do not depend on
metadata string matching for routing or reply linkage.

Recommended schema direction:

1. Add `reply_to_message_id` on assistant messages to explicitly link `A1 -> A`.
2. Add `source_message_id` on `chat_tasks` so each async/OpenClaw task records
   which user message triggered it.
3. Keep pending async execution state on `chat_tasks` (or a future task-specific
   table), rather than encoding a one-to-one future reply id on the message row.
4. Add indexes/constraints so reply linkage stays intra-user and lookup remains
   efficient.

## Todos

- Confirm the exact schema migration shape for `reply_to_message_id` and
  `chat_tasks.source_message_id`.
- Update platform export/create/patch logic to read/write first-class reply
  columns instead of metadata-only workflow markers.
- Decide whether transient assistant placeholder rows should remain visible in
  `chat_messages` or move to a non-message status path.
- Add tests covering delayed OpenClaw replies, explicit reply references, and
  mixed default/OpenClaw ordering.

## Notes

- `write_seq` already gives the desired DB ordering for late replies like
  `A, B, B reply, A reply`.
- The active client ordering bug is primarily a UI merge issue, not a DB
  ordering limitation.
- A separate relation table is possible, but likely overkill for the current
  one-reply-per-user-message model.
- `expected_reply_message_id` on `chat_messages` is no longer recommended,
  because future branching can produce multiple child replies for a single
  source message.
- Runtime evidence from local OpenClaw + platform API:
  - Plugin state shows processed event IDs and assistant client-token mappings
    for five historical OpenClaw events, so those events reached
    `handleMessageCreated(...)`.
  - The state file still contains `pendingAck` and the persisted cursor remains
    `cur_0`.
  - Direct `GET /api/v1/platform/events` with the configured plugin token works,
    but direct `POST /api/v1/platform/events/ack` returns `500 INTERNAL_ERROR`.
  - Querying events after the pending cursor shows newer events waiting
    unprocessed, so the runner is currently blocked on ack retry before it can
    fetch subsequent messages.
  - Vercel error logs confirm the server-side cause: `ackPlatformEvents()`
    emitted PostgreSQL-only SQL that Turso/libSQL rejects with
    `SQL_PARSE_ERROR`.
  - Implemented fix: keep the existing PostgreSQL `jsonb_set + UNNEST` batch
    update for Postgres, and use a Turso/libSQL-specific atomic
    `json_patch(json_object(...))` batch update instead.

## Implementation update

- `apps/node_openclaw_plugin` no longer replies with the hard-coded
  `收到消息：...` echo.
- The runner now resolves Bricks conversation topology, maps it to a stable
  OpenClaw session key (`channelId` base session plus `:thread:<threadId>` when
  applicable), and dispatches the inbound turn through OpenClaw's real
  `recordInboundSessionAndDispatchReply(...)` pipeline.
- OpenClaw-visible reply payloads are accumulated back into the reserved Bricks
  assistant placeholder row, so the user sees one assistant message updated as
  OpenClaw produces text/media output.
- The runner persists `clientToken -> messageId` immediately after placeholder
  creation so retries reuse the same assistant row if OpenClaw dispatch fails
  after the placeholder was already created.
- Validated locally with:
  - `cd apps/node_openclaw_plugin && npm test`
  - `cd apps/node_openclaw_plugin && npm run type-check`
  - `cd apps/node_openclaw_plugin && npm run build`
  - a 10-second real runtime smoke start using the user's configured
    `~/.openclaw/openclaw.json`, which booted successfully on cursor
    `cur_1883`.
- Follow-up lifecycle completion:
  - The Bricks channel plugin now implements `gateway.startAccount/stopAccount`
    so OpenClaw gateway, not a manually launched shell process, owns the pull
    runner lifecycle.
  - Verified against real gateway logs in `~/.openclaw/logs/gateway.log`:
    - `starting Bricks pull runner`
    - `[node_openclaw_plugin] started with cursor: cur_1892`
    - `stopping Bricks pull runner`
    - `[node_openclaw_plugin] stopped`
  - This means “true reply” now comes from the full OpenClaw-managed path:
    Bricks event -> gateway-managed plugin runner -> OpenClaw internal
    AI/session pipeline -> Bricks message writeback.
- Follow-up rate-limit completion:
  - The repeated `429` loop was caused by two problems together:
    - authenticated `/api/v1/platform/*` polling still shared the coarse
      generic `/api/*` IP limiter (`100 / 15 min / IP`)
    - the plugin retried platform failures on a fixed poll interval, so once it
      hit `429` it kept hammering the same limit bucket
  - Backend fix:
    - authenticated platform requests now bypass the generic app limiter
    - `apps/node_backend/src/routes/platform.ts` now applies a dedicated
      platform limiter with separate read/write budgets, stable structured `429`
      responses, and `Retry-After`
  - Plugin fix:
    - `PlatformHttpError` now captures `Retry-After`
    - the runner now treats `429` and retryable platform failures as backoff
      signals (`2s -> 4s -> 8s -> 10s`, while preferring backend-provided
      `Retry-After` when present)
  - Validated with:
    - `cd apps/node_backend && npm test -- --run src/app.test.ts src/routes/platform.test.ts`
    - `cd apps/node_backend && npm run type-check`
    - `cd apps/node_backend && npm run build`
    - `cd apps/node_openclaw_plugin && npm test`
    - `cd apps/node_openclaw_plugin && npm run type-check`
    - `cd apps/node_openclaw_plugin && npm run build`
    - real `openclaw gateway restart` plus `~/.openclaw/logs/gateway.log`
      sampling, which showed the old runner stop, the new runner restart on
      `cur_1892`, and no new sampled `429` lines after the restart
- Follow-up replay/writeback diagnosis:
  - The OpenClaw session log for `sessionId=cd08fd10-ef3c-42fa-a8d8-7b06011c0eb3`
    shows two runs of the same Bricks user message `msg-1776707308374-8`.
  - The earlier run produced a normal assistant reply (`信号非常清晰，我已经收到了...`),
    which strongly suggests the original user turn was answered inside OpenClaw.
  - A later replay of that same message produced only `<think>\nNO_REPLY`, after
    which OpenClaw's embedded runner surfaced the generic visible error
    `⚠️ Agent couldn't generate a response. Please try again.`
  - This means the observed `payloads=0`/`NO_REPLY` behavior is most likely a
    retry artifact after an earlier final Bricks writeback failure, not proof
    that the initial model run generated no answer.
- Follow-up plugin hardening:
  - The runner now persists accumulated visible reply text to
    `clientTokenReplyTextMap` before attempting the platform patch/writeback.
  - That lets a later retry recover the original OpenClaw answer even when the
    first writeback attempt fails after payload generation.
  - Added a regression test covering the sequence “reply generated -> writeback
    fails -> reply text remains persisted for retry recovery”.
  - Revalidated `apps/node_openclaw_plugin` successfully with:
    - `npm test`
    - `npm run type-check`
    - `npm run build`
  - Restarted the local gateway again and verified a fresh Bricks runner start
    at `cur_1896` in `~/.openclaw/logs/gateway.log`.
- Latest undeployed live behavior clarification:
  - The UI marker `task:accepted · id:...` is an optimistic/local async task
    placeholder created by the client before `/api/chat/respond` completes.
  - On the async OpenClaw backend path, the server persists the user message and
    returns `mode=async/state=accepted`, but it does not persist the plugin
    assistant placeholder at that moment.
  - The visible assistant row `Node OpenClaw Plugin 正在处理...` is created later
    only after the plugin successfully polls the platform event and calls
    `/api/v1/platform/messages`.
  - During the newest undeployed test, plugin state remained at `cur_1902` and
    the runtime log recorded `retryable platform failure; backing off for
    653000ms` at `2026-04-21T02:19:47+08:00`, which means the plugin hit the
    remote backend's old limiter before `getEvents(...)` returned newer events.
  - Therefore the UI can legitimately show `task:accepted` while showing no
    plugin placeholder at all: the app-side async task was created, but the
    plugin never reached the event-processing/writeback stage.
