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
