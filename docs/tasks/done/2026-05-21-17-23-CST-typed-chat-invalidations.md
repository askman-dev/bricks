# Typed Chat Invalidations

## Background

The frontend previously refreshed all chat topology endpoints after terminal SSE
task snapshots. That reduced stale channel/thread UI, but it over-fetched
`/api/chat/scopes`, `/api/chat/channel-names`, and `/api/chat/scope-settings`
for ordinary chat replies and could trigger local 429 rate limits.

## Goals

- Surface backend tool-driven changes as typed invalidations.
- Let the Flutter client refresh only the affected chat data.
- Keep existing SSE transport shape by carrying invalidations in message
  metadata.
- Preserve a coarse fallback for older snapshots that have no invalidation data.

## Implementation Plan

1. Add backend invalidation derivation from successful local agent tool results.
2. Persist invalidations on tool-step messages and aggregate them onto final
   assistant message metadata.
3. Parse invalidations from server message metadata in Flutter.
4. Replace terminal-task blanket topology refresh with typed invalidation
   consumption and targeted endpoint reloads.
5. Add parser tests for SSE invalidations.

## Acceptance Criteria

- A channel rename tool call emits `chat.channelNames` and the frontend reloads
  channel names only.
- Channel/thread creation emits `chat.scopes`, allowing the frontend to reload
  scopes and names as needed.
- Instruction changes emit `chat.scopeSettings` and the frontend reloads scope
  settings only.
- Ordinary chat completion without invalidations does not call all topology
  endpoints.

## Validation Commands

- `cd apps/node_backend && npm test -- src/routes/chat.test.ts`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
