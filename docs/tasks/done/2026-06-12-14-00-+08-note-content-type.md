# Note Content Type

## Background

### Context

Bricks already has a user-level **Resources** system for persisting structured content outside of chat and browsing it from the **Resources** tab in chat navigation. Supported content types today include:

- **Todo List** — todo lists and their items; managed via REST API and Agent internal tools (`todolist_*`, `todo_*`).
- **Asset Table** — dynamic tables with column/row schema operations and higher maintenance cost.
- **Text Highlight** — persisted message highlights; primarily read-only queries.

Resources are typed on both backend and frontend: backend invalidation kinds in `chat.ts` (e.g. `resources.todoLists`), and frontend `ChatResourceType` plus the type filter bar.

### Problem

Users need a **lightweight text container** for daily work logs and quick notes, with Agent-driven read and append flows in conversation. Existing types are a poor fit:

- **Todo** is task-oriented (title / completed) and not suited to long text or line-level edits.
- **Asset Table** is for structured tabular data and carries schema maintenance overhead unsuitable for journal/notebook use.
- **Chat markdown rendering** is display-only inside message bubbles, not a user-managed persistent resource.

### Motivation

**Note** is positioned as a **slimmed-down Markdown**: basic text with a small formatting subset, without full rich rendering. All content **reads and writes go through Agent tool calls** (same internal-tools / MCP pattern as Todo and Table). There is **no user-facing body editor**. Tools include **line-oriented read/write** (similar to an editor reading specific lines), enabling natural-language actions such as “what did I do today?” or “append this summary to line 3 of this week’s log.”

Primary use case: **work journal** — the user asks the Agent to create or open a Note and record daily items; later turns query, summarize, or append via conversation.

## Requirement

Add a user-level content type **Note** with the following product behavior:

### 1. Lifecycle and publishing

- Like Todo, Note is a **maintained** first-class resource: create, rename, publish/unpublish, delete; lifecycle supported by both REST API and Agent tools.
- Note supports **publishing** (active / visible): only published Notes appear in the Resources list, Agent tool catalog, and scope-referenced resources configuration. Unpublished Notes retain data but are hidden from Agent listing and Resources browsing (align with Todo List / User Skill active semantics; exact field name TBD at implementation).
- Note **does not support manual user editing**: no manual body editor in v1 or by design; writes, updates, and line reads are done only via **conversation-triggered Agent tool calls** (same MCP tool pattern as Todo / Table). The UI is read-only preview only.
- Note **does not need table-style schema management**: no columns, schema migrations, or column registry; content is plain text (or a restricted format subset).

### 2. Functional positioning

- Note is **simplified Markdown**:
  - Storage and mutation are **line-oriented** (newline-delimited plain text as the primary model).
  - Supports a **restricted format subset** (exact syntax TBD; e.g. heading lines, unordered lists, simple bold; **out of scope**: tables, deep nesting, full CommonMark compatibility).
- The Agent operates on content through **Note-specific internal tools** (same tool-call pipeline as existing MCP tools), at minimum:
  - Read a line range (e.g. `startLine` / `endLine`).
  - Append lines, update specific lines, delete specific lines (exact tool surface refined during implementation).
- The UI provides **read-only preview** only (title and body summary or full text in the Resources tab); no body editing.

### 3. Use cases

- **Work journal / notebook**: via conversation, the Agent creates independent documents such as “2026-06-12 Work Log” or “Weekly Journal” and records items line by line; the user can say “append today’s PR summary to today’s log” or “read the first 20 lines of this week’s log.”
- **Structure**: each Note is an **independent document** (`id`, title, body). No Todo-style parent “list + items” hierarchy. Multiple Notes are distinguished by title and updated time; Notebook grouping is a future iteration.

### 4. Resources configuration

- Note must be registered in **resources type configuration** alongside existing types:
  - Backend: extend resources invalidation / SSE refresh kinds (e.g. `resources.notes`).
  - Frontend: extend `ChatResourceType`, `ChatResourceTypeFilter`, Resources tab icons and filters.
  - Agent: expose Note CRUD and line-level read/write via internal tools and REST routes.
- In chat navigation **Resources**, Notes appear as **atomic resources** sorted by updated time (or the same unified sort rule as other types), alongside Todo List, Asset Table, and Text Highlight.

### 5. Limits

- **Per-user Note count**: no limit in v1.
- **Per-Note line count**: tentatively capped at **10,000 lines** per Note. Appends or updates that would exceed this limit are rejected with a clear error; Agent tools and REST routes enforce the same rule.

### Terminology

| Display name | Stable ID | Meaning |
|--------------|-----------|---------|
| Note | `note` | User-facing type label; storage/API use stable ID `note` |
| Published | `isActive` / `published` (TBD) | Controls visibility in Resources and Agent catalog |
| Document | single `note` record | Each Note is standalone; no parent Notebook / Note List container |
| Max lines | `10000` (tentative) | Hard cap on line count per Note; no per-user Note count cap |

## Non-goals (v1)

- No manual Note body editing UI — **not supported**; users never edit Note content directly in the app; Agent tools write back.
- No full Markdown editor or reuse of chat-level Markdown rendering for Note preview.
- No Asset Table-style schema / column maintenance.
- No attachments, collaborative editing, or version history (separate future requests).
- No cross-user Note sharing.

## Acceptance Criteria

- Given a signed-in user, when the user asks the Agent to create a Note titled “2026-06-12 Work Log” and publish it, then the Note appears in chat navigation Resources as a **standalone document** (no parent Notebook / Note List) and is listed in the Agent tool catalog.
- Given a published Note with multiple lines of text, when the Agent calls a read-lines tool for lines 5–10, then the system returns those lines (with line numbers or equivalent positioning) and no unrelated data.
- Given a published Note, when the Agent calls an append-lines tool within the **10,000-line** limit, then content is persisted, the Resources list updated timestamp refreshes, and the user sees the new lines in the read-only Resources preview.
- Given a published Note, when the Agent calls an append-lines tool that would bring the Note beyond **10,000 lines**, then the operation is rejected with an explicit limit error and the Note content is unchanged.
- Given a signed-in user with many Notes, when the user or Agent creates another Note, then creation succeeds with **no per-user Note count cap**.
- Given a user viewing a Note in the Resources preview, when the user attempts to edit the body, then no edit entry point is offered; changes only happen via later conversation and Agent tools.
- Given an unpublished Note, when the user browses Resources or the Agent lists available Notes without an explicit ID, then that Note is omitted; when republished by ID, it becomes visible again.
- Given a successful Note Agent tool call, when subsequent messages are sent in the same channel/thread, then SSE / invalidation behaves like `resources.todoLists` and client Resources data stays consistent with chat-side resource references.
- Given resources type configuration includes `note`, when a developer looks up Note entry points in `feature_map.yaml`, then REST routes, Agent tool names, and migration file indexes are documented (after implementation, maintained via code maps).

## Open Questions

1. Exact boundaries of the restricted Markdown subset (is plain text + lists enough for v1?).
