# Channel New UI Harness

This harness validates the sidebar **New Channel** flow with a real Flutter web
app, the local backend, and Turso/libSQL persistence checkpoints.

Run from the repository root:

```sh
tools/evidence/channel_new_ui_harness/run.sh
```

The script reads `.env.local`, starts the local backend and a static Flutter web
debug build when needed, drives the UI in Chromium, runs API and direct Turso
checkpoints, and writes evidence under:

```text
.cache/evidence/channel-new-ui/<run-id>/
```

Required `.env.local` values:

```text
TURSO_DATABASE_URL
TURSO_AUTH_TOKEN
JWT_SECRET
BRICKS_TEST_TOKEN
BRICKS_API_BASE_URL
FIXTURE_USER_ID
```

Default API endpoint:

```text
BRICKS_API_BASE_URL=http://localhost:3010
```

The generated channel name defaults to:

```text
E2E New Channel <run-id>
```

Override it when needed:

```sh
CHANNEL_NAME="E2E New Channel manual-check" \
tools/evidence/channel_new_ui_harness/run.sh
```

## Checkpoints

The harness records:

- `auth-me.json`: confirms the injected `BRICKS_TEST_TOKEN` works.
- `api-before.json`: confirms the generated name is absent before the test.
- `db-before.json`: direct Turso query before the test.
- `<run-id>-backend.log`: local backend log.
- `<run-id>-flutter-build.log`: Flutter web build log.
- `<run-id>-flutter.log`: static Flutter web server log.
- `<run-id>-01-initial-sidebar.png`: sidebar before clicking New Channel.
- `<run-id>-01b-new-channel-dialog.png`: New Channel dialog after opening.
- `<run-id>-01c-channel-name-entered.png`: New Channel dialog after entering the name.
- `<run-id>-02-after-create-sidebar.png`: UI state immediately after submitting.
- `api-after-create.json`: `/api/chat/channel-names` after create.
- `db-after-create.json`: direct `chat_channel_names` row after create.
- `<run-id>-02b-after-reopen-sidebar.png`: sidebar after close and reopen.
- `<run-id>-03-after-refresh-sidebar.png`: sidebar after browser refresh.
- `summary.json`: pass/fail checkpoint map and diagnosis.

## Failure Reading

- `uiAfterCreate` fails: local UI state or sidebar props did not update after
  the New Channel dialog.
- `apiAfterCreate` fails: the UI flow completed but the API did not persist or
  return the name.
- `dbAfterCreate` fails: the API and direct Turso data source disagree.
- `uiAfterReopen` fails: reopening the sidebar overwrote or lost the local
  channel list.
- `uiAfterRefresh` fails: the persisted row exists but startup hydration or
  sidebar list assembly did not restore it.

This harness writes a real row when pointed at cloud Turso. Use the
`E2E New Channel` prefix so manual cleanup and DB inspection stay simple.
