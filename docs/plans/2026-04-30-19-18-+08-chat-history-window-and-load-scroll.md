# Chat History Window and Load Scroll

## Background

The chat history load path and the message list load-position strategy have two separate ordering concerns:

- The initial history window should represent the latest conversation messages in the same semantic order used by the timeline.
- The message list should land near the latest conversation content after a page refresh or scope load.

Current investigation against production data for `session:default:main` showed that the history response itself is complete for the observed session (`limit=100` and `limit=500` both returned the same 97 messages) and the local message order around `哈哈哈` is correct. That rules out this specific production symptom being caused by a truncated backend window.

However, the backend history window still uses `write_seq DESC LIMIT N`, while the Flutter timeline comparator now uses `seqId` as the primary semantic ordering key. Earlier repository plans explain why this changed: `writeSeq` is a sync/update cursor and can conflict with semantic conversation order when async replies, late updates, or historical upserts occur. `seqId` is the immutable insertion order and is the current timeline source of truth when available.

The remaining refresh-position bug is still under discussion. With the observed data and the current `main` code, `MessageList` should focus the latest user message (`你问问 Gemini`) rather than `哈哈哈`. Therefore the likely failure is in the frontend positioning action, not the returned data order.

Additional UI observation: on first load, Chinese text can appear as missing-glyph squares before the real text renders. This strongly suggests that initial scroll positioning can run before font and text layout are stable. Combined with a large default history load and dynamic-height Markdown rows, the first `jumpTo(maxScrollExtent)` can land on a deterministic but wrong middle offset, then the one-shot `ensureVisible` can fail or become stale after font/layout changes.

## Goals

- Align the backend initial history window with the frontend timeline ordering contract.
- Keep `writeSeq` for incremental sync, SSE, plugin event cursors, and update detection.
- Preserve `seqId` as the primary semantic ordering key for loaded timeline display.
- Reduce the initial history load to a small latest-message window that fits the actual refresh use case.
- Add upward pagination so older messages are loaded only when the user scrolls upward.
- Fix the immediate bug where page refresh can remain near a middle message despite complete, correctly ordered data.
- Use the latest message as the first-phase load anchor; defer nuanced tail-preview rules such as "last two lines" until the basic latest-message landing is reliable.

## Implementation Plan

1. **Backend history window alignment**
   - Add or split a history-specific service path that selects the latest messages by semantic conversation order.
   - Use `seq_id DESC LIMIT N` for the initial history window when `seq_id` is available, then return the selected rows in `seq_id ASC` order.
   - Keep `syncMessages(... afterSeq > 0)` and event/cursor paths ordered by `write_seq ASC`.
   - Support backward pagination by accepting a stable conversation-order cursor such as `beforeSeqId` and returning the previous page in ascending display order.

2. **Initial load size and upward pagination**
   - Change the Flutter default history load from 100 messages to 10 latest messages.
   - Add a top-of-list trigger that loads older messages when the user scrolls near the beginning of the currently loaded list.
   - Prepend older pages without disturbing the visible scroll position, so the message the user was reading remains anchored after pagination.
   - Track whether more older messages are available and avoid duplicate concurrent page loads.

3. **Frontend ordering contract check**
   - Keep `compareChatMessagesByCreatedTime` using `seqId` as primary when both messages have it.
   - Keep `writeSeq` as a fallback for mixed/local or cursor-derived messages where `seqId` is absent.
   - Add or adjust tests that make the history window and timeline comparator contract explicit.

4. **Refresh scroll diagnosis and stabilization**
   - Instrument or otherwise verify the load-time `MessageList` path:
     - loaded message count and last few message roles/ids,
     - computed focused index,
     - scroll position before and after the jump,
     - whether `_focusedItemKey.currentContext` is null,
     - whether any later rebuild restores or preserves an old scroll offset.
   - Verify whether Chinese font fallback/loading changes text layout after the first scroll positioning attempt.
   - Consider explicit CJK-capable font configuration or font preload if missing-glyph squares persist in production.
   - In the first implementation phase, anchor load-time positioning to the latest message rather than the latest user message.
   - Defer latest-tail preview policies, such as anchoring to the final two lines, to a follow-up decision after latest-message landing is stable.
   - Decide whether the message list should disable or scope scroll offset persistence for page refresh and conversation-scope changes.
   - Make the final load-time scroll action resilient to delayed font/layout stabilization and dynamic-height rows.

5. **Code maps and documentation**
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` if implementation changes history loading, timeline ordering, scroll behavior, or regression test indexes.

## Acceptance Criteria

- Initial chat history loads the latest conversation-window rows according to the same semantic ordering used by the timeline.
- Refresh initially requests and renders only the latest 10 messages for the active conversation scope.
- Scrolling upward near the top loads older messages and prepends them without causing the visible content to jump.
- Repeated upward pagination can recover older conversation history until no older messages remain.
- Incremental sync and SSE continue to use `writeSeq` cursor semantics and do not miss late updates.
- Rows where `writeSeq` conflicts with `seqId` still render in semantic conversation order.
- Refresh/load scroll behavior lands on the latest message in the first phase and is verified against the production-shaped case where `哈哈哈` is in the middle of a complete response.
- The first-phase fix does not attempt to implement "last two lines" or other tail-preview anchoring rules.
- Chinese text does not first render as missing-glyph squares in normal production loading, or scroll positioning is delayed/retried until text layout is stable.
- The final implementation has targeted backend and Flutter tests for the changed ordering and scroll behavior.
- Code maps are updated when the implementation lands, or the final notes explain why no code-map update is needed.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/chat_message_sort_test.dart test/message_list_test.dart test/chat_history_api_service_test.dart`
- `npm test -- --runInBand apps/node_backend/src/services/chatAsyncTransportService.test.ts apps/node_backend/src/routes/chat.test.ts`
