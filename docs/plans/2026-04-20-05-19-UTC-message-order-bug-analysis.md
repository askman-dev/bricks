# Background
A message ordering bug is reported for session `session:default:sub-1776598618924-10`: newer messages sometimes render above older messages in the front-end timeline. The task is to use readonly Turso environment variables to inspect persisted data and identify the likely root cause.

# Goals
1. Connect to the readonly Turso database using the provided environment variables.
2. Inspect message/task records for the target session and verify whether database ordering is stable by creation time.
3. Correlate database ordering behavior with UI symptoms and identify the most likely bug source.
4. Produce actionable remediation guidance (query/index/sort key strategy) and validation checks.

# Implementation Plan (phased)
## Phase 1: Locate schema and read paths
- Find tables and columns storing messages/events for sessions.
- Find server/client code paths that query and render timeline data.
- Identify current `ORDER BY` strategy and tie-breakers.

## Phase 2: Database evidence collection
- Connect with `TURSO_DATABASE_URL_READONLY` and `TURSO_AUTH_TOKEN_READONLY`.
- Pull records for `session:default:sub-1776598618924-10` and compare:
  - `created_at` order
  - insertion/key order (e.g., `id`, `rowid`)
  - any event timestamp fields used by UI.
- Detect equal timestamps or mixed precision that can produce nondeterministic ordering.

## Phase 3: Root-cause analysis and fix proposal
- Determine whether the issue is caused by DB query ordering, merge logic, or front-end sort.
- Propose exact ordering contract (primary + tie-breaker keys) from oldest to newest.
- Add a concise analysis artifact in-repo for maintainers.

# Acceptance Criteria
- A reproducible data snapshot demonstrates why unstable ordering occurs for the target session.
- The analysis maps symptoms to concrete columns/query behavior in code.
- A clear fix recommendation is documented, including deterministic ordering keys and validation command(s).

# Investigation Notes (2026-04-20)
- Connected to Turso read-only endpoint using provided in-memory credentials (not persisted to files).
- Session inspected: `session:default:sub-1776598618924-10`.
- Row count: `18`.
- Confirmed same-timestamp collisions in this session:
  - `2026-04-19T19:38:10.305` has 2 rows (`write_seq` 1757..1758).
  - `2026-04-19T23:41:38.860` has 2 rows (`write_seq` 1764..1765).
- Code-path analysis still identifies a deterministic ordering gap:
  - Backend returns messages ordered by monotonic `write_seq`.
  - Mobile client discarded `writeSeq` and re-sorted by `createdAt` only.
  - When multiple rows share the same `createdAt` (common under async writes / second-level collisions), UI order depends on fallback keys and can drift from actual write order.
- Implemented remediation in app code:
  1. Parse and carry `writeSeq` in `ChatMessage`.
  2. Use `writeSeq` as tie-breaker when `createdAt` is equal.
  3. Added regression test verifying equal-`createdAt` messages keep `writeSeq` order.

## Direct answers to review questions

### 1) “How do you confirm there are same-timestamp conflicts?”
- Confirmed from live DB rows in your target session with this grouping query:
  - `SELECT created_at, COUNT(*), MIN(write_seq), MAX(write_seq) ... GROUP BY created_at HAVING COUNT(*) > 1`.
- Result shows 2 concrete collision groups:
  - `2026-04-19T19:38:10.305` (`write_seq` 1757..1758),
  - `2026-04-19T23:41:38.860` (`write_seq` 1764..1765).

### 2) “Do you read data?”
- Yes. Read directly from Turso with readonly token in-memory and queried `chat_messages` for your session.
- Verification SQL used:

```sql
SELECT
  message_id,
  write_seq,
  created_at
FROM chat_messages
WHERE session_id = 'session:default:sub-1776598618924-10'
ORDER BY created_at ASC, write_seq ASC;
```

Then check collisions:

```sql
SELECT
  created_at,
  COUNT(*) AS n
FROM chat_messages
WHERE session_id = 'session:default:sub-1776598618924-10'
GROUP BY created_at
HAVING COUNT(*) > 1
ORDER BY created_at ASC;
```

### 3) “What is the precision of create time? Can it hit this condition?”
- Effective precision in this dataset is mixed:
  - some rows are second-level style (e.g. `2026-04-19 11:37:11`),
  - some rows are millisecond ISO strings (e.g. `2026-04-19T23:41:38.860`).
- So yes, same-`created_at` condition is real (observed above), and timeline ordering must include deterministic tie-breakers (e.g., `writeSeq`) rather than relying on `createdAt` alone.

## Screenshot flow re-check
- Re-checked against the provided screenshots: the timeline shows mixed clock representations (`11:37`, `15:41`, `23:41`) and user/assistant blocks that can be affected by inconsistent `created_at` semantics across write paths.
- This means “`createdAt` primary + `writeSeq` only tie-break” is insufficient for some real flows: order can still drift even when timestamps are not exactly equal.
- Updated comparator strategy to:
  1. use `writeSeq` as primary key whenever both messages have it (server-synced rows),
  2. fallback to `createdAt/timestamp` only when `writeSeq` is unavailable.
- Added regression test that reproduces “clock order disagrees with write order” and verifies the list still follows `writeSeq`.
