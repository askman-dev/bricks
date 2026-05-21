# Evidence Checkpoint Browser Harness

Use this pattern when a bug can only be trusted through the running app: a real
browser action, the local API, and the database state all have to agree.

The channel New UI harness is the reference implementation:

```sh
tools/evidence/channel_new_ui_harness/run.sh
```

## Environment Shape

The default shape is:

- real Flutter web app
- local backend API
- explicit test token or local auth bypass
- selected database target, either a local fixture DB or cloud Turso
- one fixture user identity
- evidence written under ignored `.cache/` paths

For cloud Turso runs, the database is shared but the visible product data is
still user-scoped. A row created for `FIXTURE_USER_ID` will not appear for a
different logged-in production user. When comparing harness output with the
deployed product, first confirm all three scopes match:

- database URL
- user ID
- channel/thread/session scope, when relevant

## Checkpoint Layers

Prefer multiple small checkpoints over one end-to-end assertion. Each checkpoint
should answer a different question.

Recommended layers:

- Auth checkpoint: the injected token reaches `/api/auth/me` and resolves to the
  expected fixture user.
- Initial API checkpoint: the target record or name is absent before the test,
  so the run is not passing because of stale data.
- Initial database checkpoint: a direct query confirms the same absence in the
  database target.
- UI action checkpoint: the browser performs the same click/type/confirm flow a
  user performs.
- Immediate UI checkpoint: the visible UI updates without requiring a refresh.
- API after-action checkpoint: the local API returns the created or changed
  record.
- Direct database after-action checkpoint: the row exists in the selected DB for
  the expected user and scope.
- Reopen or route-switch checkpoint: local UI state survives closing and opening
  the relevant surface.
- Refresh checkpoint: startup hydration restores the visible state from
  persisted data.

This structure makes failures actionable. If the UI checkpoint passes but the
API checkpoint fails, the issue is likely in persistence. If the API and DB
checkpoints pass but refresh fails, the issue is likely in startup hydration or
list assembly.

## Artifact Rules

Use a run ID with sortable wall-clock time:

```text
YYYYMMDD-HHMMSS
```

Prefix logs and screenshots with the same run ID:

```text
20260521-113252-02-after-create-sidebar.png
20260521-113252-backend.log
```

Keep machine-readable checkpoint files stable across runs:

```text
auth-me.json
api-before.json
db-before.json
api-after-create.json
db-after-create.json
summary.json
```

The stable names make scripts easy to consume, while the timestamped visual
artifacts stay naturally ordered in the file browser.

## Failure Reading

When a checkpoint fails, read from the bottom of the stack upward:

- Database row missing: the API may not have written, may be using a different
  database, or may be writing under a different user/scope.
- API sees the row but direct DB does not: the API and direct query are pointed
  at different data sources or filters.
- UI does not update immediately but API/DB pass: the client state update or
  sidebar list assembly is suspect.
- UI updates only after refresh: the creation path did not refresh the open
  surface, but startup hydration can read the data.
- UI disappears after refresh while API/DB pass: startup hydration or persisted
  display-name mapping is suspect.
- Harness data not visible in production: compare database URL, logged-in user
  ID, and channel/thread/session scope before assuming the write failed.

## Safety

Do not commit secrets, tokens, generated JWTs, raw DB exports, screenshots, or
logs. If a harness writes to cloud Turso, use a recognizable prefix such as
`E2E` in generated names so manual inspection and cleanup stay simple.
