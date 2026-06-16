# Background
The repository currently supports issuing one OpenClaw platform token from settings, but lacks a first-class Node model that can bind tokens to specific runtimes (local machine, cloud runtime, etc.).

# Goals
- Implement node management APIs and persistence in backend.
- Make platform token issuance node-aware while keeping existing JWT algorithm unchanged.
- Add Settings UI for node list/create/rename and node-scoped token copy/install instructions.
- Display node attribution in assistant messages instead of generic ask where node metadata is available.
- Add tests for backend and Flutter changes.

# Implementation Plan (phased)
## Phase 1: Backend foundation
1. Add DB migration for `platform_nodes`.
2. Add service for CRUD/list + default-name generation.
3. Add `/api/config/nodes` endpoints and node-aware `/api/config/platform-token`.

## Phase 2: Chat metadata & attribution
1. Extend platform message persistence metadata with `nodeName` using plugin id mapping.
2. Update chat message mapping/rendering fallback to show node name chip.

## Phase 3: Mobile settings UX
1. Add Node Settings entry in settings screen.
2. Add node list page with empty-state create button, rename, token generation, copy actions.
3. Reuse existing install-instruction format with node-scoped pluginId/token.

## Phase 4: Validation and docs/index updates
1. Run backend unit tests and mobile flutter tests.
2. Update code maps for new entry points and logic indexes.

# Acceptance Criteria
- Users can create and rename multiple nodes in settings.
- Platform token can be generated for a specific node and includes node-bound pluginId.
- Assistant message attribution shows node name when available.
- Backend + Flutter tests pass for new behavior.
