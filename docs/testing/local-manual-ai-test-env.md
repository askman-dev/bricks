# Local Manual AI Test Environment

Use this workflow when a human needs to open Bricks in a browser, click
`Quick Login (Test)`, type real messages, and receive model replies while the
backend writes to a selected database target.

This is intentionally a manual test environment, not an automated evidence
harness. For automated checkpoint testing, see
`docs/testing/evidence-checkpoint-browser-harness.md`.

## Shape

The standard setup is:

- local Node backend, usually `http://127.0.0.1:3010`
- local Flutter Web debug build, usually `http://127.0.0.1:8082`
- cloud Turso database from `.env.local`
- `AUTO_MIGRATE=false` when using cloud Turso
- `Quick Login (Test)` using `BRICKS_TEST_TOKEN`
- one fixture user from `FIXTURE_USER_ID`
- optional real LLM provider config created for that fixture user

Rows written by this setup belong to `FIXTURE_USER_ID`. They will not appear
for a different logged-in production user, even when both environments point at
the same Turso database.

## Required `.env.local`

Keep `.env.local` out of Git. Required values:

```text
TURSO_DATABASE_URL
TURSO_AUTH_TOKEN
JWT_SECRET
ENCRYPTION_KEY
FIXTURE_USER_ID
BRICKS_TEST_TOKEN
PORT=3010
BRICKS_API_BASE_URL=http://127.0.0.1:3010
AUTO_MIGRATE=false
```

For Gemini manual reply testing, also add:

```text
GEMINI_API_KEY=<real key>
GEMINI_MODEL=gemini-flash-latest
```

Do not paste real provider tokens into chat. Put them in `.env.local` and have
commands read from the environment.

## Start Backend

Run from the repository root:

```sh
set -a
source .env.local
set +a
export PORT="${PORT:-3010}"
export AUTO_MIGRATE="${AUTO_MIGRATE:-false}"
cd apps/node_backend
npm run dev
```

Health check:

```sh
curl -sS http://127.0.0.1:3010/api/health
```

## Create Fixture-User Gemini Config

Run this only when the fixture user needs a real model config. The key is read
from `.env.local` and written through the local backend, which encrypts it
before storing it in Turso.

```sh
set -a
source .env.local
set +a

node <<'NODE'
const base = process.env.BRICKS_API_BASE_URL || 'http://127.0.0.1:3010';
const token = process.env.BRICKS_TEST_TOKEN;
const apiKey = process.env.GEMINI_API_KEY;
const model = process.env.GEMINI_MODEL || 'gemini-flash-latest';
const endpoint =
  process.env.GEMINI_ENDPOINT || 'https://generativelanguage.googleapis.com';

if (!token || !apiKey) {
  throw new Error('Missing BRICKS_TEST_TOKEN or GEMINI_API_KEY');
}

const headers = { Authorization: `Bearer ${token}` };
const response = await fetch(`${base}/api/config`, {
  method: 'POST',
  headers: { ...headers, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    category: 'llm',
    provider: 'google_ai_studio',
    is_default: true,
    config: {
      slot_id: model,
      endpoint,
      api_key: apiKey,
      model_preferences: { default_model: model },
    },
  }),
});

const body = await response.text();
if (!response.ok) {
  throw new Error(`config create failed ${response.status}: ${body}`);
}

const parsed = JSON.parse(body);
console.log(JSON.stringify({
  id: parsed.id,
  provider: parsed.provider,
  is_default: parsed.is_default,
  default_model: parsed.config?.model_preferences?.default_model,
  endpoint: parsed.config?.endpoint,
}, null, 2));
NODE
```

## Encryption Boundary

The local backend uses `ENCRYPTION_KEY` to encrypt provider tokens before
writing `api_configs` rows. The same local backend can read those rows later as
long as it uses the same `ENCRYPTION_KEY`.

If a deployed backend uses a different `ENCRYPTION_KEY`, it may not be able to
decrypt a fixture-user config created locally. That is expected and should not
affect a real production user because rows are scoped by user ID.

## Build And Serve Flutter Web

In another shell from the repository root:

```sh
set -a
source .env.local
set +a

cd apps/mobile_chat_app
flutter build web --debug \
  --dart-define=BRICKS_API_BASE_URL="${BRICKS_API_BASE_URL:-http://127.0.0.1:3010}" \
  --dart-define=BRICKS_TEST_TOKEN="$BRICKS_TEST_TOKEN"
```

Serve the build:

```sh
node tools/evidence/channel_new_ui_harness/static_server.mjs \
  apps/mobile_chat_app/build/web \
  8082
```

Open:

```text
http://127.0.0.1:8082/
```

Click `Quick Login (Test)`, enter the chat, type a message, and send it.

## Verify Runtime Wiring

Use these probes before trusting a manual test:

```sh
curl -sS http://127.0.0.1:3010/api/health
```

```sh
set -a
source .env.local
set +a

node <<'NODE'
const base = process.env.BRICKS_API_BASE_URL || 'http://127.0.0.1:3010';
const token = process.env.BRICKS_TEST_TOKEN;
const headers = { Authorization: `Bearer ${token}` };
const [me, configs] = await Promise.all([
  fetch(`${base}/api/auth/me`, { headers }),
  fetch(`${base}/api/config?category=llm`, { headers }),
]);
const meBody = await me.json();
const configBody = await configs.json();
const llm = Array.isArray(configBody)
  ? configBody.find((item) => item.is_default) || configBody[0]
  : null;
console.log(JSON.stringify({
  authStatus: me.status,
  userId: meBody.user?.id || meBody.userId || null,
  configStatus: configs.status,
  defaultProvider: llm?.provider || null,
  defaultModel: llm?.config?.model_preferences?.default_model || null,
}, null, 2));
NODE
```

Do not print provider keys in verification output.

## Shutdown

Find listeners:

```sh
lsof -nP -iTCP:3010 -sTCP:LISTEN
lsof -nP -iTCP:8082 -sTCP:LISTEN
```

Stop the matching PIDs when finished:

```sh
kill <pid>
```
