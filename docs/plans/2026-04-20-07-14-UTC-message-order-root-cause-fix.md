# Message ordering root-cause fix plan (session:default:sub-1776598618924-10)

## Background
The UI showed assistant replies before their corresponding user queries for `session:default:sub-1776598618924-10`.
Live Turso rows confirm this is not only a same-timestamp collision problem:
- For the same task IDs, assistant rows have lower `write_seq` than user rows in several pairs.
- The same rows keep immutable `seq_id` order as user -> assistant.
- `created_at` format is mixed (`YYYY-MM-DD HH:MM:SS` and ISO8601 with timezone), indicating inconsistent timestamp sources/parsing.

## Goals
1. Ensure rendered order follows semantic conversation order (user prompt before assistant reply).
2. Avoid using mutable sync cursor (`write_seq`) as a chronological ordering key.
3. Normalize timestamp parsing for legacy DB values without timezone suffix.
4. Add regression tests that model the DB-observed inversion pattern.

## Implementation Plan (phased)
1. **Model and mapping updates**
   - Add `seqId` to `ChatMessage` and parse from server payload.
   - Keep `writeSeq` for sync cursor semantics only.
2. **Ordering logic updates**
   - Update comparator: `seqId` primary (when available), then `createdAt/timestamp`, then role/messageId.
   - Keep deterministic fallback behavior for mixed/local-only messages.
3. **Timestamp parsing normalization**
   - Parse server `createdAt` strings without timezone as UTC to avoid local-time misinterpretation.
4. **Regression tests**
   - Add/adjust tests for `seqId` vs `writeSeq` conflict and no-timezone UTC parsing behavior.
5. **Code map sync**
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` to reflect the corrected ordering strategy.

## Acceptance Criteria
- Given rows where `write_seq` contradicts prompt/reply semantics, rendered order remains user-before-assistant using `seqId`.
- Given `createdAt` in `YYYY-MM-DD HH:MM:SS`, displayed local time reflects UTC-origin input rather than raw local parsing.
- `cd apps/mobile_chat_app && flutter test test/chat_message_sort_test.dart` passes.
- `cd apps/mobile_chat_app && flutter test test/chat_message_test.dart` passes (or equivalent parsing-focused tests).
