# Bricks × OpenClaw Pull-Only Integration Development Document

## 1. Scope and objective
This document defines an implementation-ready backend integration contract for Bricks to support OpenClaw plugin development in **pull-only** mode.

Primary objective:
- Bricks acts as the platform system of record for conversation/message/interaction/binding events.
- OpenClaw Plugin acts as a local adapter that pulls events from Bricks and writes agent output back to Bricks.
- OpenClaw Core continues to own runtime semantics (loop, prompt, tool orchestration, dispatch, session internals).

Out of scope:
- Webhook push from Bricks to plugin
- Reverse tunnel / local ingress networking
- Re-implementing OpenClaw Core runtime responsibilities in Bricks

---

## 2. Architecture decision

### 2.1 Topology
- Bricks exposes HTTPS APIs.
- Plugin makes outbound HTTPS calls to Bricks.
- Plugin/OpenClaw local runtime exposes **no inbound HTTP endpoint**.

### 2.2 Rationale
This model eliminates inbound networking dependencies and keeps platform responsibilities centralized:
- No public IP dependency for local plugin runtime
- No webhook reachability requirement
- Clear platform-consumer ownership boundary

---

## 3. Responsibility boundaries

### 3.1 Bricks product/UI layer
Must support:
1. Channel/thread/DM display
2. User and agent messages display
3. Markdown/code block/streaming/interactions rendering
4. User interaction submission
5. Conversation primary-agent binding edits

UI principle: user actions are persisted to Bricks backend; UI does not directly talk to OpenClaw Core.

### 3.2 Bricks platform API layer
Must provide:
1. Durable storage for conversation/message/interaction/binding
2. Pullable event stream API
3. Message write-back APIs
4. Conversation topology resolve API
5. Optional DM metadata/access checks
6. Event ACK, cursor, idempotency primitives

### 3.3 OpenClaw plugin layer
Must provide:
1. Event polling loop
2. Dedup and ACK behavior
3. Raw topology -> OpenClaw session input translation
4. Agent output write-back
5. Control-plane binding_changed handling
6. DM policy / pairing / channel-level guard checks

### 3.4 OpenClaw core layer
Keeps ownership of runtime internals:
- Agent loop, prompt ownership/wiring, dispatch
- Shared message tools, session-key shape, thread bookkeeping
- Skill/tool orchestration
- Approval lifecycle and token/context management
- Sandbox/policy execution controls

---

## 4. Session model constraints

### 4.1 Thread sessions
Thread conversations must be treated as independent session inputs. Do not assume implicit inheritance of short-term parent context.

### 4.2 DM sessions
For multi-user Bricks workspaces, plugin should default to granular DM scoping (recommended: `per-channel-peer`) instead of shared global DM session behavior.

---

## 5. Authentication model (API key only)

### 5.1 Principle
Only plugin->Bricks requests exist in pull-only topology. Therefore, API key bearer auth is sufficient.

### 5.2 Required headers
All plugin calls include:

```http
Authorization: Bearer <BRICKS_API_KEY>
Content-Type: application/json
X-Bricks-Plugin-Id: <plugin_id>
X-Bricks-Client-Version: <plugin_version>
```

### 5.3 API key storage model (Bricks)
Recommended minimum persisted fields:

```json
{
  "keyId": "bpk_01JZ...",
  "keyHash": "sha256(...)",
  "workspaceId": "ws_123",
  "pluginId": "plugin_local_main",
  "scopes": ["events:read", "events:ack", "messages:write", "conversations:read", "dm:check"],
  "status": "active",
  "createdAt": "2026-04-14T10:00:00Z",
  "lastUsedAt": "2026-04-14T10:10:00Z"
}
```

Security requirements:
- Store hash only, never plaintext
- Plaintext returned once at create time
- Key scoped to workspace/tenant
- Support revoke/rotate/audit trail

### 5.4 Scope profile
MVP minimum:
- `events:read`
- `events:ack`
- `messages:write`
- `conversations:read`

Optional (DM safety):
- `dm:check`

---

## 6. API surface

Base URL: `{BRICKS_BASE_URL}` (example: `https://bricks.askman.dev`)

### 6.1 MVP required APIs (minimal closed loop)
1. `GET /api/v1/platform/events`
2. `POST /api/v1/platform/events/ack`
3. `POST /api/v1/platform/messages`
4. `PATCH /api/v1/platform/messages/{messageId}`
5. `GET /api/v1/platform/conversations/resolve`

### 6.2 Optional enhancement APIs
6. `GET /api/v1/platform/conversations/{conversationId}`
7. `POST /api/v1/platform/dm/access-check`

---

## 7. Contract details

### 7.0 Canonical error response
All non-2xx responses should use the same body shape:

```json
{
  "error": {
    "code": "INVALID_CURSOR",
    "message": "cursor is malformed",
    "retryable": false
  },
  "requestId": "req_01JZ..."
}
```

`code` must be stable and machine-readable. `message` is human-readable. `retryable` indicates whether automatic retry is recommended.

### 7.1 `GET /api/v1/platform/events`
- Purpose: pull pending events.
- Query: `cursor`, `limit`
- Delivery: at-least-once
- Ordering: stable per cursor window, not global exactly-once

Status codes:
- `200 OK`: events returned (possibly empty list)
- `400 BAD REQUEST`: invalid `cursor` or `limit`
- `401 UNAUTHORIZED`: missing/invalid API key
- `403 FORBIDDEN`: key lacks `events:read`
- `429 TOO MANY REQUESTS`: rate limited
- `5xx`: transient platform failure

Success response:
```json
{
  "nextCursor": "cur_000124",
  "events": [
    {
      "eventId": "evt_001",
      "eventType": "message.created",
      "workspaceId": "ws_123",
      "conversationId": "conv_1001",
      "rawId": "discord:channel:123/thread:456",
      "occurredAt": "2026-04-14T10:00:00Z",
      "payload": {
        "messageId": "msg_u_001",
        "sender": {
          "userId": "user_01",
          "displayName": "Kimi"
        },
        "text": "帮我解释这段代码",
        "attachments": []
      }
    }
  ]
}
```

### 7.2 `POST /api/v1/platform/events/ack`
- ACK only after plugin dedup state persisted and event enqueued into OpenClaw Core input queue.
- Plugin identity is canonical from required header `X-Bricks-Plugin-Id`.
- Request body must not include `pluginId`; if provided, backend should reject with `400 BAD REQUEST`.
- `cursor` is the `nextCursor` received from the latest successful `GET /events` response whose events are being acknowledged.
- ACK is idempotent: re-sending already-acked `eventId`s must still return success.
- Unknown `eventId`s should be ignored (no hard failure) and reported in metrics/audit logs.

Request:
```json
{
  "ackedEventIds": ["evt_001", "evt_002"],
  "cursor": "cur_000124"
}
```

Response:
```json
{ "ok": true }
```

Status codes:
- `200 OK`: ACK applied (including idempotent re-ACKs)
- `400 BAD REQUEST`: malformed body, invalid cursor semantics, or forbidden `pluginId` body field
- `401 UNAUTHORIZED`: missing/invalid API key
- `403 FORBIDDEN`: key lacks `events:ack`
- `429 TOO MANY REQUESTS`: rate limited
- `5xx`: transient platform failure

### 7.3 `POST /api/v1/platform/messages`
- Idempotent create by `clientToken`.

Request:
```json
{
  "workspaceId": "ws_123",
  "conversationId": "conv_1001",
  "author": {
    "type": "agent",
    "agentId": "agent_reviewer",
    "displayName": "Reviewer"
  },
  "clientToken": "out_001",
  "content": {
    "format": "markdown",
    "text": "我先看一下这段代码的结构。"
  },
  "status": "streaming"
}
```

Response:
```json
{
  "messageId": "msg_a_9001",
  "revision": 1
}
```

Status codes:
- `200 OK`/`201 CREATED`: message created
- `200 OK`: idempotent replay by existing `clientToken`
- `400 BAD REQUEST`: malformed payload
- `401 UNAUTHORIZED`: missing/invalid API key
- `403 FORBIDDEN`: key lacks `messages:write`
- `409 CONFLICT`: `clientToken` reused with non-equivalent payload
- `422 UNPROCESSABLE ENTITY`: semantic validation failure
- `429 TOO MANY REQUESTS`: rate limited
- `5xx`: transient platform failure

### 7.4 `PATCH /api/v1/platform/messages/{messageId}`
- `revision` must increase monotonically.
- Reject stale updates (`<= current revision`) with `409 CONFLICT`.
- Exactly one of `append` or `replace` is required.
- If both are provided, return `400 BAD REQUEST`.
- If neither is provided, return `400 BAD REQUEST`.

Streaming patch:
```json
{
  "revision": 2,
  "append": "\n\n发现一个明显问题：异常分支没有释放资源。",
  "status": "streaming"
}
```

Completed patch:
```json
{
  "revision": 3,
  "replace": "发现一个明显问题：异常分支没有释放资源，可能导致连接泄漏。",
  "status": "completed"
}
```

Status codes:
- `200 OK`: patch applied
- `400 BAD REQUEST`: invalid patch shape (including append/replace rule violations)
- `401 UNAUTHORIZED`: missing/invalid API key
- `403 FORBIDDEN`: key lacks `messages:write`
- `404 NOT FOUND`: message does not exist
- `409 CONFLICT`: stale or non-monotonic revision
- `422 UNPROCESSABLE ENTITY`: semantic validation failure
- `429 TOO MANY REQUESTS`: rate limited
- `5xx`: transient platform failure

### 7.5 `GET /api/v1/platform/conversations/resolve`
- Converts Bricks topology object into session-grammar input for plugin mapping.

Status codes:
- `200 OK`: topology resolved
- `400 BAD REQUEST`: malformed query
- `401 UNAUTHORIZED`: missing/invalid API key
- `403 FORBIDDEN`: key lacks `conversations:read`
- `404 NOT FOUND`: conversation not found/inaccessible
- `429 TOO MANY REQUESTS`: rate limited
- `5xx`: transient platform failure

### 7.6 Optional metadata/access APIs
- `GET /conversations/{conversationId}` for metadata
- `POST /dm/access-check` for DM security gating

---

## 8. Event model
MVP event types:
1. `message.created`
2. `interaction.submitted`
3. `conversation.binding_changed`

Control plane vs message plane:
- `binding_changed` is control-plane event carried by event stream.
- Message output remains message-plane via `messages` APIs.

---

## 9. Plugin processing loop
Recommended fixed loop:
1. Poll `GET /events`
2. Dedup by `eventId`
3. Resolve conversation topology
4. Translate to OpenClaw input
5. Enqueue into core queue
6. ACK consumed events
7. Create output message
8. Stream patch updates until completed

---

## 10. Binding update flow
1. User changes conversation primary agent in Bricks UI.
2. Bricks persists binding as source of truth.
3. Bricks emits `conversation.binding_changed` event.
4. Plugin translates to OpenClaw binding config update.
5. Plugin applies via **`config.patch`** (not full `config.apply`) so only binding delta changes.

---

## 11. Error handling and idempotency

### 11.1 Event consumption
Plugin must persist:
- processed `eventId` set
- local cursor
- crash-recovery replay protections

### 11.2 Message creation
Use `clientToken` idempotency key.

### 11.3 Streaming updates
Use `revision` sequencing.

### 11.4 Retry policy
- `GET /events` timeout: immediate reconnect
- `POST /events/ack` failure: short retry; do not mark complete locally until success
- `POST /messages` failure: retry with same `clientToken`
- `PATCH /messages/{id}` failure: reload current local revision and retry forward

---

## 12. Data model recommendations

### 12.1 Bricks tables
- `conversations`
- `messages`
- `platform_events`
- `conversation_bindings`
- `api_keys`

### 12.2 Plugin local state
- `lastCursor`
- `processedEventIds`
- `clientToken -> messageId`
- pending write-back retry queue

---

## 13. Delivery phases

### Phase 1 (minimal closed loop)
Implement required 5 APIs and only `message.created`.

### Phase 2 (thread + binding)
Add `conversation.binding_changed` handling and plugin `config.patch` sync.

### Phase 3 (DM + security)
Add optional metadata/access APIs and `dmScope=per-channel-peer` policy.

---

## 14. Engineering constraints
1. Bricks message payload must not carry runtime routing directives like target agent.
2. Plugin must not bypass OpenClaw core to build prompts.
3. Bricks must not duplicate OpenClaw session bookkeeping logic.
4. Binding changes must flow via control-plane events.
5. API keys must be revocable, rotatable, auditable.

---

## 15. Operational checklist
Before production rollout:
- [ ] API key lifecycle endpoints (create/revoke/rotate/list) ready
- [ ] Rate limiting by workspace + plugin ID in place
- [ ] Event lag and ACK lag metrics exported
- [ ] Message write latency metrics exported
- [ ] Revision conflict (`409`) metrics exported
- [ ] Structured audit logs include plugin ID, key ID, workspace ID
- [ ] End-to-end replay test validates at-least-once + dedup resilience
