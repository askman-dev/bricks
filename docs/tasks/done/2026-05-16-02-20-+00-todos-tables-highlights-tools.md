# Todos, Asset Tables, Text Highlights – Unified MCP Tool Architecture

## Background

### Context

The platform already has an agent loop (`localAgentLoopService.ts`) with a small set of
internal tools for chat-management actions (channel rename, create, instruction-set, etc.).
The `buildAgentTools()` function returns an AI-SDK-compatible tool registry closed over
`userId`, and `executeInternalTool()` dispatches each named tool to a typed handler.
The pattern is clean and proven; new domains should follow it exactly.

The Flutter UI shows AI tool-call progress via `agentLoopPhase = 'tool_call_start'`
messages, and renders tool results as Markdown in `_AssistantMarkdownText`.

### Problem

Three new user-facing features are needed, none of which have any backend or UI code yet:

1. **Todo list** – users want to say "create a todo: buy milk" and have the AI call a
   tool, storing it persistently. Querying ("show my todos") should return a Markdown list.
2. **Asset tables** – users want AI-driven dynamic tables: add/remove columns, add/update/delete
   rows, all via natural language. The JSONB sparse-storage pattern (separate column registry +
   `cell_data JSONB` on rows) allows schema changes without touching row data.
3. **Text highlights** – users want to select text in a message bubble, right-click (or
   long-press), choose "Highlight", and have that selection persist across reloads. The AI
   should be able to answer "what are my highlights?" by calling a `highlight_list` tool.

### Motivation

All three features share the same integration surface: Postgres for persistence, typed
service modules, new `INTERNAL_TOOL_*` constants, and Flutter API services. Building them
together under one plan keeps the architecture consistent and avoids ad-hoc divergence.

## Goals

- Implement persistent todo-list CRUD entirely via the existing internal-tool infrastructure.
- Implement JSONB-backed asset tables with column-level schema operations (add/remove column)
  that are O(1) in row count.
- Implement text-highlight storage and a Flutter context-menu entry that persists selections.
- Expose all three domains via both the AI agent loop (tool calls visible to the user) and
  a REST API so the Flutter client can perform direct CRUD without going through the AI.
- Maintain the existing single-file tool registry pattern (`localAgentLoopService.ts`).

## Implementation Plan

### Phase 1 – Database Migrations

1. **`015_create_user_todos.sql`** – `user_todos` table:
   ```
   id UUID PK, user_id UUID FK, title TEXT NOT NULL, notes TEXT,
   is_completed BOOLEAN DEFAULT FALSE, display_order INT DEFAULT 0,
   created_at TIMESTAMP, updated_at TIMESTAMP
   ```
   Index on `(user_id, is_completed)`.

2. **`016_create_asset_tables.sql`** – three tables:
   - `asset_tables`: `id UUID PK, user_id UUID FK, resource_id VARCHAR(255), title TEXT, created_at, updated_at` – UNIQUE `(user_id, resource_id)`
   - `asset_table_columns`: `id UUID PK, user_id UUID FK, resource_id VARCHAR(255), column_key VARCHAR(255), display_name TEXT, column_order INT DEFAULT 0, created_at, updated_at` – UNIQUE `(user_id, resource_id, column_key)`
   - `asset_table_rows`: `id UUID PK, user_id UUID FK, resource_id VARCHAR(255), display_number INT, cell_data JSONB DEFAULT '{}', is_deleted BOOLEAN DEFAULT FALSE, created_at, updated_at`
   Index on `(user_id, resource_id)` for all three tables.

3. **`017_create_text_highlights.sql`** – `text_highlights` table:
   ```
   id UUID PK, user_id UUID FK, message_id VARCHAR(255) NOT NULL,
   selected_text TEXT NOT NULL, start_offset INT, end_offset INT,
   color VARCHAR(32) DEFAULT 'yellow',
   created_at TIMESTAMP, updated_at TIMESTAMP
   ```
   Index on `(user_id, message_id)`.

### Phase 2 – Backend Services

4. **`todoService.ts`** – `createTodo`, `listTodos`, `updateTodo`, `deleteTodo`,
   `completeTodo`. Each function takes `userId` as first arg, returns typed DTOs.

5. **`assetTableService.ts`** – functions:
   - `createTable`, `listTables`, `getTable` (with columns + rows joined)
   - `addColumn`, `removeColumn` (DELETE from `asset_table_columns`)
   - `addRow` (INSERT with cell_data), `updateRow` (JSONB merge UPDATE),
     `deleteRow` (soft-delete `is_deleted = true`)
   Reading rows always JOINs `asset_table_columns` as the authority for active columns;
   `cell_data` keys not in the column registry are silently ignored.

6. **`textHighlightService.ts`** – `createHighlight`, `listHighlights`,
   `listHighlightsByMessageId`, `deleteHighlight`.

### Phase 3 – Internal Tool Registry

7. **Add constants** to `localAgentLoopService.ts`:
   - Todo: `todo_create`, `todo_list`, `todo_complete`, `todo_update`, `todo_delete`
   - Table: `table_create`, `table_list`, `table_get`, `table_add_column`,
     `table_remove_column`, `table_add_row`, `table_update_row`, `table_delete_row`
   - Highlight: `highlight_list` (read-only; manual create is done from Flutter)

8. **Extend `executeInternalTool()`** with `switch` cases for every new constant,
   delegating to the service functions added in Phase 2.

9. **Extend `buildAgentTools()`** with AI-SDK tool definitions (description + parametersSchema)
   for every new constant. Tool results for todo/table should return data that the model can
   format as Markdown for the user.

### Phase 4 – REST Routes

10. **`resources.ts`** – Express router at `/api/resources`, authenticated:
    - `GET /todos`, `POST /todos`, `PATCH /todos/:id`, `DELETE /todos/:id`
    - `GET /tables`, `POST /tables`, `GET /tables/:resourceId`,
      `POST /tables/:resourceId/columns`, `DELETE /tables/:resourceId/columns/:columnKey`,
      `POST /tables/:resourceId/rows`, `PATCH /tables/:resourceId/rows/:rowId`,
      `DELETE /tables/:resourceId/rows/:rowId`
    - `GET /highlights`, `POST /highlights`, `DELETE /highlights/:id`

11. **Register** in `app.ts`: `app.use('/api/resources', resourcesRoutes)`.

### Phase 5 – Flutter Client

12. **`todo_api_service.dart`** – service class mirroring the REST surface;
    methods: `listTodos`, `createTodo`, `updateTodo`, `completeTodo`, `deleteTodo`.

13. **`asset_table_api_service.dart`** – `listTables`, `getTable`, `createTable`,
    `addColumn`, `removeColumn`, `addRow`, `updateRow`, `deleteRow`.

14. **`text_highlight_api_service.dart`** – `listHighlights`, `createHighlight`,
    `deleteHighlight`.

15. **Text highlight context menu in `message_list.dart`**:
    - Each assistant message bubble wraps content in a `SelectionArea` child. Use
      `ContextMenuController` / `AdaptiveTextSelectionToolbar` to intercept the platform
      context menu, inject a "Highlight" button.
    - On "Highlight": read the selected text + approximate character range, POST to
      `/api/resources/highlights`, then call `setState` to add the highlight to an in-memory
      map and re-render the message with a `TextSpan(background: highlightColor)`.
    - On screen load: `GET /api/resources/highlights` filtered by current channel/session,
      populate the in-memory highlight map before first render.

## Acceptance Criteria

- User types "add a todo: finish the report" and sees the AI emit a `tool_call_start` bubble
  followed by a confirmation message listing the new todo item.
- User types "show my todos" and the AI calls `todo_list`, then responds with a Markdown
  checklist of todos.
- User types "create a table called Tasks with columns Name and Status" and the AI calls
  `table_create` then `table_add_column` twice; a subsequent "show the Tasks table"
  returns a Markdown table.
- User types "add a column Priority to Tasks table" and the AI calls `table_add_column`
  with O(1) DB cost (no row UPDATE required).
- User selects text in an assistant message bubble and sees a "Highlight" option in the
  context menu. After tapping, the selected text appears with a yellow background.
- After reloading the app (or reopening the channel), the highlight is still visible on
  the same message.
- User types "what are my highlights?" and the AI calls `highlight_list`, returning the
  stored highlighted texts in a readable list.
- All existing tests pass; no regressions on chat, channel, or agent-loop behaviour.

## Validation Commands

- `cd apps/node_backend && npm run build`
- `cd apps/node_backend && npm test`
- `cd apps/mobile_chat_app && flutter analyze`
- `cd apps/mobile_chat_app && flutter test`
