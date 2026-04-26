# OpenClaw Integration

This page summarizes the current OpenClaw integration surface implemented in this repository.

## Integration model

- Backend platform API prefix: `/api/v1/platform/*`
- Plugin authentication: Bearer token + `X-Bricks-Plugin-Id`
- Data model: reuses existing `chat_messages` storage
- Token retrieval: app settings flow + backend token endpoint

## API capabilities

- `GET /api/v1/platform/events`
- `GET /api/v1/platform/events/stream?cursor=...` (SSE – used by plugin client for event consumption)
- `POST /api/v1/platform/events/ack`
- `POST /api/v1/platform/messages`
- `PATCH /api/v1/platform/messages/:messageId`
- `GET /api/v1/platform/conversations/resolve`

## Auth mode

Current reference implementation in `apps/node_openclaw_plugin` uses JWT-only startup flow.

## Where to read implementation details

- [`docs/plugin_development_architecture.md`](../plugin_development_architecture.md)
- `apps/node_backend/src/routes/platform.ts`
- `apps/node_openclaw_plugin/src/pluginRunner.ts`
