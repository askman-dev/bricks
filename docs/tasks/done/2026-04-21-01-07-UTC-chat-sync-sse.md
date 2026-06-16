# Replace Long Polling with SSE for Chat Sync

**Date:** 2026-04-21 01:07 UTC

## Background

PR #174 introduced long-polling on `GET /api/chat/sync/:sessionId` (via a `waitMs` query
parameter) to reduce the number of empty short-poll round-trips when multi-agent group
conversations are idle.  A review comment on that PR argued—correctly—that SSE (Server-Sent
Events) is a strictly better transport for the same use-case because:

* A single persistent HTTP connection replaces the repeated TCP/TLS handshake-tear-down cycle
  of long-polling.
* The server can push multiple events (one per bot reply) over the same open pipe.
* AI streaming "typewriter" output maps naturally onto SSE frames.
* SSE's `EventSource` reconnect semantics are well-understood and free of the state-management
  complexity that long-poll reconnection requires.

## Goals

1. Remove long-polling (`waitMs`, the retry loop, `sleep()`) from the sync endpoint.
2. Add a new `GET /api/chat/events/:sessionId` SSE endpoint on the Node.js backend.
3. Replace the Flutter timer-based polling with a persistent SSE stream subscription.
4. Keep the simple (non-long-poll) `GET /api/chat/sync/:sessionId` endpoint intact for
   on-demand fetches (e.g. after history load).
5. Update all affected tests.

## Implementation Plan

### Phase 1 – Backend (`apps/node_backend/src/routes/chat.ts`)

* Remove `CHAT_SYNC_LONG_POLL_MAX_WAIT_MS`, `CHAT_SYNC_LONG_POLL_INTERVAL_MS`, `sleep()`.
* Revert the `/sync/:sessionId` handler to a simple single-call `syncMessages` + `res.json`.
* Add `GET /events/:sessionId` handler:
  * Rate-limited at 10 new connections / user / session / minute (`eventsLimiter`).
  * Sets `Content-Type: text/event-stream`, `Cache-Control: no-cache`, `Connection: keep-alive`.
  * Sends `setInterval` keep-alive heartbeat comments every 15 s.
  * Polls `syncMessages` every 1 s via `setTimeout`; when new data arrives writes
    `data: <JSON>\n\n` and advances `afterSeq`.
  * Cleans up timers on `req.on('close')`.

### Phase 2 – Flutter service (`apps/mobile_chat_app/lib/features/chat/chat_history_api_service.dart`)

* Remove `waitMs` parameter from `_syncUri()` and `sync()`.
* Add `_eventsUri(sessionId, afterSeq)` URI helper.
* Add `Stream<ChatHistorySnapshot> listenEvents({token, sessionId, afterSeq})` using
  `http.Client.send()` for a streaming response, parsing SSE lines into snapshots.

### Phase 3 – Flutter screen (`apps/mobile_chat_app/lib/features/chat/chat_screen.dart`)

* Replace `Timer? _syncTimer`, `bool _syncInFlight`, backoff fields with
  `StreamSubscription<ChatHistorySnapshot>? _sseSubscription`.
* Replace `_cancelSyncPolling` → `_disconnectSse`.
* Replace `_scheduleSync` / `_configureActiveScopeSync` / `_syncActiveScope` with
  `_connectSse` / `_configureActiveScopeSync` / `_applySseSnapshot`.
* On SSE stream error or done: reconnect after `_sseReconnectDelay` (3 s) if still mounted
  and scope hasn't changed.

### Phase 4 – Tests

* **Backend** (`chat.test.ts`): remove long-poll retry test; add SSE streaming test that reads
  `response.body` as a `ReadableStream` and asserts a `data:` line with the expected payload.
* **Flutter** (`chat_history_api_service_test.dart`): remove `waitMs` assertion; add two SSE
  tests using `_MockStreamedClient` (a `BaseClient` subclass) that controls a
  `StreamController<List<int>>` to emit raw SSE bytes.

## Acceptance Criteria

* `GET /api/chat/events/:sessionId` responds with `Content-Type: text/event-stream` and
  pushes `data:` frames within ~1 s of new messages being inserted.
* `GET /api/chat/sync/:sessionId` continues to work without `waitMs` (no long-poll loop).
* Flutter app opens one SSE connection per active scope, updates the message list on each
  incoming event, and reconnects automatically if the stream drops.
* All existing backend tests pass; new SSE test passes.
* All existing Flutter tests pass; two new SSE stream tests pass.
* `flutter analyze lib/features/chat/` reports no errors in modified files.

## Validation Commands

```sh
# Backend
cd apps/node_backend && npm test -- src/routes/chat.test.ts

# Flutter
cd apps/mobile_chat_app && flutter test test/chat_history_api_service_test.dart
cd apps/mobile_chat_app && flutter analyze lib/features/chat/
```
