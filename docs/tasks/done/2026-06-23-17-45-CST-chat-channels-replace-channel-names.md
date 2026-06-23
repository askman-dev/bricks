# Chat Channels Replace Channel Names

## Background

The current chat sidebar and thread model uses `chat_channel_names` as the persisted name store for both channels and thread-like subsections. Archive currently calls the channel-name endpoint with `displayName: null`, which is semantically wrong because archive is a lifecycle state, not a name deletion.

Threads do not need a separate `threads` table. In the current product model, a thread is a scoped chat surface under a channel. The storage identity can be represented by `(user_id, channel_id, thread_id)`.

`/api/chat/scopes` currently reconstructs channels and threads from message/task history and scope settings. That should stop being the source of visible sidebar entities. It can remain as an activity query, but it must not create channel or thread rows in the UI.

## Goals

- Replace `chat_channel_names` with a single `chat_channels` registry for both top-level channels and thread/subsection scopes.
- Add explicit lifecycle state through `archived_at` instead of overloading nullable display names.
- Make channel and thread visibility depend on `chat_channels`, not historical message/task fallback.
- Keep storage identity separate from display naming.
- Avoid adding a separate `threads` table.

## Implementation Plan

1. Add a `chat_channels` database table keyed by `(user_id, channel_id, thread_id)`.
2. Store top-level channels with the normalized main-thread value for `thread_id`.
3. Store thread/subsection rows with the same `channel_id` and a non-main `thread_id`.
4. Include `display_name`, `scope_type`, `archived_at`, `source`, `generated_name_attempted_at`, `created_at`, and `updated_at`.
5. Migrate existing `chat_channel_names` rows into `chat_channels`.
6. Replace channel-name backend services and routes with channel lifecycle routes for create, rename, archive, and list.
7. Update frontend channel and thread hydration to list visible rows from `chat_channels`.
8. Downgrade `/api/chat/scopes` to return activity metadata only; frontend may join that activity onto existing `chat_channels` rows but must not create visible channels or threads from scopes.
9. Remove frontend archive behavior that calls the name endpoint with `displayName: null`.
10. Stop reading and writing `chat_channel_names` after migration.
11. Update code maps for the changed chat feature entry points, backend business logic, and tests.

## Acceptance Criteria

- Creating a channel persists a `chat_channels` top-level row.
- Renaming a channel updates `chat_channels.display_name`.
- Archiving a channel sets `chat_channels.archived_at` and removes it from the active sidebar list.
- Creating a thread persists a `chat_channels` row under the parent channel with a non-main `thread_id`.
- Renaming a thread updates the corresponding `chat_channels.display_name`.
- Archiving a thread sets `chat_channels.archived_at` and removes it from the active thread list.
- `/api/chat/scopes` no longer causes old message/task history to appear as visible sidebar channels by itself.
- Existing channel names from `chat_channel_names` are preserved after migration.
- The frontend no longer sends archive requests to `/api/chat/channel-names`.

## Validation Commands

- `./tools/init_dev_env.sh`
- `npm test`
- `cd apps/mobile_chat_app && flutter analyze`
- `cd apps/mobile_chat_app && flutter test`
