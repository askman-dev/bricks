# Thread Auto Name Source

## Background

Thread display names are stored separately from scope settings in `chat_channel_names`.
New Channels already have a user-entered name, but new Threads can be created
without a display name and then appear as raw thread IDs until a manual rename
or a later refresh path supplies a name.

## Goals

- Keep the existing name table model.
- Add source metadata for display names.
- Give unnamed non-main Threads an immediate exact name from the first message.
- After the first assistant reply completes, attempt one generated title for
  Threads still named by `first_message_exact`.
- Avoid extra frontend requests and avoid overwriting manual names.

## Implementation Plan

1. Extend `chat_channel_names` with `source` and `generated_name_attempted_at`.
2. Add service helpers for exact-name insertion, generation claiming, and
   conditional generated-name completion.
3. Invoke the helpers from the backend `/api/chat/respond` async flow.
4. Notify the existing frontend through typed `chat.channelNames` invalidations.
5. Add backend unit coverage and a repeatable evidence harness.

## Acceptance Criteria

- Existing UI/API/manual rename paths write `source = manual`.
- For non-main Threads with no name, the first user message inserts
  `source = first_message_exact`.
- Only one generated-name attempt can be claimed per Thread.
- A generated name only updates rows still at `source = first_message_exact`.
- Manual names are never overwritten by automatic generation.
- E2E evidence proves exact and generated naming through the real app/API path.

## Validation Commands

- `cd apps/node_backend && npm test -- src/routes/chat.test.ts src/services/localAgentLoopService.test.ts`
- `cd apps/node_backend && npm run type-check`
- `tools/evidence/thread_auto_name_source/run.sh`
