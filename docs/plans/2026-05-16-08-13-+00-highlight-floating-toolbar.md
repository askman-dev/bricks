# Highlight Floating Toolbar

## Background

### Context

The text highlight feature has partial infrastructure in place:

- `TextHighlightApiService` — CRUD API client for highlights (create / delete / list by messageId).
- `HighlightSpan` / `_AssistantMarkdownText` — renders highlights as a semi-transparent yellow background over matching text spans inside assistant messages.
- `MessageList` — accepts `highlights: Map<String, List<HighlightSpan>>` and `onHighlight` callback, and inserts a "划线" button into the system `AdaptiveTextSelectionToolbar` when text is selected.

**However**, `ChatScreen` does not wire up these props — it passes `MessageList(messages: _messages)` with no highlights map and no `onHighlight` callback, so the highlight system is completely disconnected end-to-end.

### Problem

1. The `ChatScreen` never loads highlights from the API and never passes them to `MessageList`, so no persisted highlights are ever shown.
2. The current selection toolbar is the platform's default `AdaptiveTextSelectionToolbar`, which is positioned by the OS and visually inconsistent. The custom "划线" entry is appended to the end of whatever system buttons the OS provides.
3. There is no **copy** or **hide** button in the custom toolbar (copy exists in the default system buttons, but is not part of any custom-styled bar).
4. There is no **delete highlight** action — a user cannot remove an existing highlight.
5. Tapping an already-highlighted span does nothing.

### Motivation

The user expects a cohesive, discoverable experience:
- Slide-select → custom floating toolbar with 划线 / 复制 / 隐藏.
- Tap an already-highlighted span → floating toolbar with 删除划线 / 复制 / 隐藏.
- Toolbar is visually positioned near the selection (above or below), not in a system default corner.

---

## Goals

- Wire up the highlight feature end-to-end: load, render, create, and delete highlights.
- Replace the system `AdaptiveTextSelectionToolbar` with a compact custom floating toolbar.
- Add **复制** (copy to clipboard) and **隐藏** (hide/fold message) actions to the toolbar.
- Show **删除划线** instead of **划线** when the selected text is already fully highlighted.
- Allow tapping any highlighted span to trigger the delete toolbar without needing a long-press/drag selection.

---

## Implementation Plan

### Phase 1 — Wire up ChatScreen

1. Add `TextHighlightApiService` instance to `_ChatScreenState` (alongside `_chatHistoryApiService`).
2. Add state field `Map<String, List<HighlightSpan>> _highlights = {}`.
3. In `_loadMessagesForActiveScope`, after messages are loaded and `_authToken` is available, call `TextHighlightApiService.listHighlights` for every `messageId` in the loaded messages that belongs to an assistant role. Group results into `_highlights` and update via `setState`. Use the same scope-staleness guard pattern already used for message loading.
4. Add `_handleCreateHighlight(String messageId, String selectedText, int? start, int? end)` method — calls `createHighlight`, then calls `listHighlights` for that `messageId` and refreshes `_highlights` via `setState`.
5. Add `_handleDeleteHighlight(String highlightId, String messageId)` method — calls `deleteHighlight`, then refreshes `_highlights` for that messageId.
6. Add `_handleHideMessage(String messageId)` stub — adds the messageId to a `Set<String> _hiddenMessageIds` state field; the message list can filter or collapse those messages (out of scope for this plan; just the stub needed here).
7. Pass `highlights`, `onHighlight`, `onDeleteHighlight`, and `onHideMessage` into the `MessageList` constructor in the `chatContent` build.

### Phase 2 — Custom floating toolbar

1. Replace `AdaptiveTextSelectionToolbar.buttonItems` in `MessageList.contextMenuBuilder` with a new private widget `_SelectionToolbar`.
2. `_SelectionToolbar` is a `Material`-wrapped `Row` of `InkWell` text buttons (pill-shaped, compact), using `ChatColors` or `Theme` tokens.
3. Buttons: **划线** (or **删除划线** if already highlighted), **复制**, **隐藏**.
4. Position using `selectableRegionState.contextMenuAnchors.primaryAnchor` (or `secondaryAnchor` if it would be off-screen).
5. To detect **"already highlighted"**: check if `_lastSelectedText` is a substring of any `HighlightSpan.selectedText` in the highlights map for any assistant message that contains the selection. Pass the relevant `highlights` map as a parameter so `contextMenuBuilder` can evaluate it synchronously.
6. **划线** action: call `widget.onHighlight` (existing callback).
7. **删除划线** action: find the matching `HighlightSpan` for the selected text and call a new `widget.onDeleteHighlight` callback.
8. **复制**: call `Clipboard.setData(ClipboardData(text: _lastSelectedText))` then `ContextMenuController.removeAny()`.
9. **隐藏**: call new `widget.onHideMessage` callback with the messageId of the message containing the selection, then dismiss.

### Phase 3 — Tap-on-highlighted-span

1. Add `onDeleteHighlight` and `onHideMessage` parameters to `_AssistantMarkdownText`.
2. In `_splitSpanByHighlights`, for each highlighted `TextSpan`, attach a `TapGestureRecognizer` that:
   - Locates the `HighlightSpan` matching that text fragment.
   - Shows a lightweight `OverlayEntry` positioned at the tap's global offset containing a `_SelectionToolbar` in "delete mode" (showing 删除划线, 复制, 隐藏 for the highlighted text). Dismiss the overlay on second tap or on any other gesture.

### Phase 4 — MessageList API additions

Add to `MessageList`'s constructor (and propagate through `_MessageListState` / `_AssistantMarkdownText`):

```
onDeleteHighlight: void Function(String highlightId, String messageId)?
onHideMessage:     void Function(String messageId)?
```

The existing `onHighlight` signature is unchanged.

---

## Acceptance Criteria

- After sliding to select text in an assistant message, a floating toolbar appears **near the selection** (not in a system corner) with buttons labeled **划线**, **复制**, and **隐藏**.
- Tapping **划线** creates a highlight via the API; the selected text gains a yellow background immediately (optimistic update or reload).
- Tapping **复制** copies the selected text to the clipboard and dismisses the toolbar.
- Tapping **隐藏** invokes the hide callback and dismisses the toolbar.
- When text that is already highlighted is selected, the **划线** button changes to **删除划线**.
- Tapping **删除划线** calls the delete API and removes the yellow background from the affected span.
- Tapping directly on a yellow-highlighted span (without dragging) shows the same toolbar in delete mode.
- After navigating away and back to a conversation, previously created highlights are still rendered.
- The floating toolbar does not appear for user-bubble messages (highlight only applies to assistant messages).

---

## Validation Commands

```sh
cd apps/mobile_chat_app && flutter analyze
cd apps/mobile_chat_app && flutter test
```
