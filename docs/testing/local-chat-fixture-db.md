# Local Chat Fixture DB

This workflow creates a local libSQL/SQLite fixture database from a remote
Turso database, then runs the normal backend and Flutter app against that local
file. It is intended for chat scroll and history-entry testing.

## Export

Run from `apps/node_backend`:

```sh
TURSO_DATABASE_URL="<remote-libsql-url>" \
TURSO_AUTH_TOKEN="<remote-token>" \
npm run fixture:export-chat
```

By default the script chooses the most recently active chat user and writes:

```text
apps/node_backend/.cache/chat-scroll-fixture.db
```

To export a specific user:

```sh
FIXTURE_USER_ID="<user-id>" \
TURSO_DATABASE_URL="<remote-libsql-url>" \
TURSO_AUTH_TOKEN="<remote-token>" \
npm run fixture:export-chat
```

The export copies chat-rendering tables only. It intentionally does not copy
`api_configs` by default because those rows may contain provider credentials.

## Backend

Run from `apps/node_backend`:

```sh
JWT_SECRET=bricks-local-test-secret \
TURSO_DATABASE_URL="file:$PWD/.cache/chat-scroll-fixture.db" \
npm run dev
```

## Test Token

In another shell, run from `apps/node_backend`:

```sh
JWT_SECRET=bricks-local-test-secret \
TURSO_DATABASE_URL="file:$PWD/.cache/chat-scroll-fixture.db" \
npm run fixture:token
```

The command prints a JWT for Flutter's test-login flow.

## Flutter Web

Run from `apps/mobile_chat_app`:

```sh
flutter run -d chrome \
  --dart-define=BRICKS_TEST_MODE=true \
  --dart-define=BRICKS_TEST_TOKEN="<token-from-fixture-token>" \
  --dart-define=BRICKS_API_BASE_URL=http://localhost:3000
```

On the login page, use `Quick Login (Test)` instead of GitHub OAuth.
