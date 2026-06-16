# Resources Tab in Navigation Sidebar

## Background

### Context

The chat navigation sidebar (`ChatNavigationPage`) currently has two tabs: **Channels** and **Nodes**. It is mounted inside a `Drawer` (or inline sidebar on desktop) and is the primary navigation surface of the mobile chat app.

There are already two resource services in the codebase:
- `TodoApiService` – manages todo-lists and their items
- `AssetTableApiService` – manages asset tables (columns + rows)

Both services return summary objects via their list endpoints: `listTodoLists()` returns `TodoList` (without items) and `listTables()` returns `AssetTableSummary`.

### Problem

Users have no way to browse or open their todo-lists and asset tables from the navigation sidebar. There is no entry point for resource discovery in the current two-tab layout.

### Motivation

A dedicated **Resources** tab between Channels and Nodes gives users a single place to see all their structured data resources at a glance. Clicking any item opens a preview page, establishing the navigation pattern for richer resource views in future iterations.

## Goals

- Add a single **Resources** tab to the navigation sidebar, positioned between Channels and Nodes.
- Display all todo-lists and all asset tables as a flat list (no section headers) in that tab, distinguished by icon.
- Tapping any resource item opens a preview page showing the resource's summary information.
- Load resource summaries during app initialisation alongside the existing platform-node loading.
- Keep the change backward-compatible: existing tests pass with minimal updates.

## Implementation Plan

1. **Data models** (`chat_navigation_page.dart`)
   - Add `enum ChatResourceType { todoList, assetTable }`.
   - Add `class ChatResourceItem` with fields: `id`, `type`, `title`, `notes` (nullable).

2. **Navigation page – Resources tab** (`chat_navigation_page.dart`)
   - Add `resources` parameter (`List<ChatResourceItem>`, defaults to `const []`) and optional `onResourceSelected` callback.
   - Change `TabController(length: 2)` → `length: 3`.
   - Update `TabBar` to show three tabs: **Channels**, **Resources**, **Nodes**.
   - Insert a new `ListView` as the middle `TabBarView` child that renders each `ChatResourceItem` with a type-specific icon (`Icons.checklist_outlined` for todo-lists, `Icons.table_chart_outlined` for tables), the title, and an optional subtitle from `notes`.
   - On tap: call `onResourceSelected` if provided; otherwise push `_ResourcePreviewPage` internally via `Navigator.of(context).push(...)`.
   - Update class doc-comment to mention the new Resources tab.

3. **Resource preview page** (`chat_navigation_page.dart`)
   - Add private `_ResourcePreviewPage` widget (like `_NodeDetailPage`) that receives a `ChatResourceItem` and displays its type icon, title, and notes in a `Scaffold` with `AppBar`.

4. **Load resources in ChatScreen** (`chat_screen.dart`)
   - Import `todo_api_service.dart` and `asset_table_api_service.dart`.
   - Add service instances `_todoApiService` and `_assetTableApiService`.
   - Add state lists `_todoLists` (type `List<TodoList>`) and `_assetTables` (type `List<AssetTableSummary>`).
   - Inside `_loadAgents()`, after auth token resolves, load both resource lists best-effort (same pattern as platform nodes) and include them in the final `setState`.
   - Build a combined `resources` list in `_buildNavigationContent` and pass it to `ChatNavigationPage`.

5. **Update tests** (`chat_navigation_page_test.dart`)
   - Rename the existing "two tabs" test to verify three tabs (Channels, Resources, Nodes).
   - Add a test for Resources tab empty state.
   - Add a test for Resources tab showing items (mixed todo-list and table items).
   - Add a test verifying tapping a resource opens the preview page.

## Acceptance Criteria

- The navigation sidebar shows three tabs: Channels, Resources, Nodes (in that order).
- The Resources tab displays a flat list of all loaded todo-lists (checklist icon) and asset tables (table icon) without section headers.
- Tapping a resource item navigates to a preview page showing the item's title and notes (if present).
- When no resources are loaded the Resources tab shows a "No resources" empty state message.
- Existing Channels and Nodes tab behaviour is unchanged.
- All existing and new widget tests pass.

## Validation Commands

- `cd apps/mobile_chat_app && flutter test test/chat_navigation_page_test.dart`
- `cd apps/mobile_chat_app && flutter analyze`
