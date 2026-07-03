# Note Content Type Implementation

## Background

Bricks already exposes persistent resources through backend REST routes, agent internal tools, and the mobile chat Resources tab. Todo lists and tables are implemented, but users cannot save long Markdown content discovered or generated during chat as a durable note document.

The existing backlog item defines Note as a first-class resource for Markdown-like long text, written through agent tools and viewed through a read-only Resources preview. This implementation focuses on the user story where chat finds useful material and the user asks the agent to save it into a Note.

## Goals

- Add a user-scoped `note` resource for long Markdown text with title, body, publication state, and timestamps.
- Expose Note lifecycle and content mutation through REST APIs and agent internal tools.
- Show published Notes in the Resources tab as standalone read-only resources.
- Preserve the existing Todo `notes` field behavior while keeping it distinct from the new Note content type.

## Implementation Plan

1. Add a database migration and backend service for `asset_notes`, including list, get, create, update metadata, delete, read lines, append lines, replace lines, and delete lines.
2. Register Note REST routes under `/api/resources/notes` with validation, line limits, and authenticated user scoping.
3. Add Note internal tools to `localAgentLoopService.ts` so the model can create Notes and save Markdown bodies from chat.
4. Add a Flutter Note API service, extend `ChatResourceType` and Resources filtering/preview, and load notes into chat navigation.
5. Add backend and Flutter tests for the new service surface and Resources UI behavior.
6. Update code maps and move the backlog task to done after validation.

## Acceptance Criteria

- A signed-in user can ask the agent to create a Note with long Markdown content and the note is persisted as a standalone resource.
- Published Notes appear in the Resources tab with a Note icon, can be filtered by type, and open in a read-only preview.
- The agent can list notes, read a line range, append lines, replace line ranges, and delete line ranges without exceeding the 10,000-line cap.
- Unpublished Notes are omitted from default Resources listing but remain retrievable by explicit ID through authenticated APIs/tools.
- Todo List/Todo Item `notes` fields continue to work unchanged.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test -- --run src/routes/resources.test.ts src/services/localAgentLoopService.test.ts`
- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null && echo "code maps yaml ok"`
