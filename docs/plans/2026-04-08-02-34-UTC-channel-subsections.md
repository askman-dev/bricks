# Channel Sub-sections (replace Thread Mode) Plan

## Background
- The chat entry flow routes authenticated users into `ChatScreen`, where conversation scope is currently encoded by `(channelId, threadId)` and persisted as `session:<channelId>:<threadId>`. 
- In current UI behavior, child conversation areas (子区) are guarded behind a runtime `Thread 模式` toggle (`_threadModeEnabled`). Without enabling it, users cannot create sub-sections.
- The backend and API already carry `threadId` fields, so scope-level message isolation exists at transport/persistence level; however, domain language and UI behavior still expose this as optional "thread mode" instead of always-available channel sub-sections.
- Product direction is to remove mode switching entirely and treat sub-sections as first-class, optional children of a channel (0..N children).

## Goals
1. Remove all user-facing and stateful "Thread mode" behavior.
2. Keep channel-level chatting available when there are zero sub-sections.
3. Support creating and entering sub-sections, each with independent chat history.
4. Make parent-child relation explicit in client topology: channel knows children; sub-section knows parent.
5. In the chat top-right sub-section menu, render two functional groups:
   - Management group (e.g., 回到主区, 新建子区)
   - Sub-section list group (navigable)
6. Sort sub-section list by each sub-section’s latest message timestamp descending.

## Implementation Plan (phased)

### Phase 1 — Topology/domain model cleanup
- Replace toggle-driven state with explicit scope model:
  - main scope is always present per channel;
  - child scopes are optional and always creatable.
- Introduce/normalize data structures so:
  - channel keeps `subSections` collection;
  - sub-section includes `parentChannelId`.
- Keep persistence identity stable (`session:<channelId>:<scopeId>`) while renaming UI/domain terms from thread -> sub-section where possible.

### Phase 2 — ChatScreen behavior migration
- Remove `_threadModeEnabled` and all toggle branches.
- Update active scope resolution to always use currently selected section (`main` or child).
- Allow creating sub-section regardless of mode.
- Ensure switching channel defaults to `main` unless previous active child remains valid for that channel.

### Phase 3 — Top-right menu UX restructuring
- Keep existing menu entry point in app bar right action.
- Render menu in two groups:
  1) Management actions (回到主区, 新建子区)
  2) Sub-section navigable items.
- Sort child list by latest message timestamp desc.
  - Maintain `lastMessageAt` index per `(channelId, subSectionId)` from in-memory messages and/or loaded history metadata.
  - Unmessaged sub-sections fall to the bottom with deterministic tie-breaker (e.g., createdAt desc then id).

### Phase 4 — Data loading/persistence alignment
- Ensure load/persist calls continue to use scope-derived `sessionId` so each sub-section history is isolated.
- Validate that creating/switching sub-sections clears current list then loads that scope’s history snapshot.
- Confirm backend payload remains compatible (`threadId` can remain wire field short-term, with UI terminology migrated).

### Phase 5 — Test updates
- Update and/or add widget tests for:
  - no-sub-section channel can still send/receive;
  - create child sub-section and navigate;
  - management group/actions visible;
  - list sorted by latest message time desc.
- Update unit tests around topology/scope resolution accordingly.

## Acceptance Criteria
1. **Zero-child baseline**: In any channel with no child sub-sections, user can directly chat in 主区 without enabling any mode or switch.
2. **Create + isolate history**: After creating a child sub-section and entering it, message history starts as a new isolated scope (does not show 主区 history); returning to 主区 restores 主区 history.
3. **Parent-child awareness**: Channel data can enumerate its child sub-sections; each child sub-section carries its parent channel identity.
4. **Menu grouping**: Top-right sub-section menu shows exactly two functional groups:
   - Group A management actions: 回到主区、新建子区
   - Group B child sub-section navigation list
5. **Menu ordering**: Group B sub-section list is ordered by latest message time descending (most recently active first).
6. **No thread toggle**: UI does not expose "开启/关闭 Thread 模式" and logic has no mode-gated behavior for sub-section creation/navigation.
7. **Backward compatibility (short-term)**: Existing backend request contracts continue functioning while client product language reflects 子区 rather than thread mode.
8. **Regression safety**: Existing channel creation/switching and message send flow still work after migration.

## Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test`
- `cd apps/mobile_chat_app && flutter analyze`
