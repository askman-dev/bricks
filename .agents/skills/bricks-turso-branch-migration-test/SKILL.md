---
name: bricks-turso-branch-migration-test
description: Use when validating Bricks database migrations against a Turso Cloud branch/test database copied from the current cloud database, then running local backend and Flutter Web against that branch database for manual verification. Covers Turso Cloud CLI setup, branch creation with --from-db, local secret-safe env handling, migration verification, and local app startup.
---

# Bricks Turso Branch Migration Test

Use this skill when a schema migration must be validated with realistic cloud data before merging or deploying to production.

## Safety Rules

- Never print `TURSO_AUTH_TOKEN`, `BRICKS_TEST_TOKEN`, `JWT_SECRET`, `ENCRYPTION_KEY`, or provider API keys.
- Keep branch/test DB env in an uncommitted local file such as `.env.migration-test.local`.
- Do not use `.env.local` directly for migration validation unless the user explicitly wants to migrate that database.
- After the branch DB has been migrated, start local backend with `AUTO_MIGRATE=false`.
- Prefer keeping old tables as deprecated rollback backups in risky migrations; drop them only in a separate cleanup migration after production validation.

## Cloud CLI

There are two similarly named tools:

- Homebrew `turso` installs `tursodb`, the embedded SQL shell. It is not the Cloud management CLI.
- Turso Cloud CLI is installed as `~/.turso/turso` by `https://get.tur.so/install.sh` or by downloading `homebrew-tap_Darwin_arm64.tar.gz` from `tursodatabase/homebrew-tap`.

Check the Cloud CLI:

```bash
~/.turso/turso --version
~/.turso/turso auth whoami
```

If not logged in, the user must run:

```bash
~/.turso/turso auth login
```

## Create A Branch/Test Database

1. Derive the source database name from `.env.local` without printing secrets:

   ```bash
   zsh -lc 'set -a; source .env.local; set +a; node -e "const u=new URL(process.env.TURSO_DATABASE_URL||\"\"); console.log(u.hostname);"'
   ```

2. If the hostname includes an org suffix, switch to the owning org:

   ```bash
   ~/.turso/turso org list
   ~/.turso/turso org switch <org-slug>
   ~/.turso/turso db list
   ```

3. Create a short branch DB name. Turso DB names must be at most 26 characters:

   ```bash
   ~/.turso/turso db create bricks-mig-0623a --from-db database-bricks --wait
   ```

4. Get the branch DB URL and token. Do not print the token:

   ```bash
   ~/.turso/turso db show bricks-mig-0623a --url
   ~/.turso/turso db tokens create bricks-mig-0623a > /private/tmp/bricks-mig-0623a.token
   ```

## Prepare Local Test Env

Create `.env.migration-test.local` from `.env.local`, but replace Turso URL/token with the branch DB values:

```bash
zsh -lc 'set -a; source .env.local; set +a; token=$(tr -d "\n" < /private/tmp/bricks-mig-0623a.token); umask 077; cat > .env.migration-test.local <<EOF
TURSO_DATABASE_URL=<branch-db-url>
TURSO_AUTH_TOKEN=$token
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
FIXTURE_USER_ID=$FIXTURE_USER_ID
BRICKS_TEST_TOKEN=$BRICKS_TEST_TOKEN
PORT=3010
BRICKS_LOCAL_DEV=true
LOCAL_LLM_CONFIG_ENABLED=false
AUTO_MIGRATE=true
EOF'
```

Use `LOCAL_LLM_CONFIG_ENABLED=false` unless the test specifically needs local provider keys. If it is `true` without a valid `LOCAL_LLM_PROVIDER` and API key, chat can fail with `Invalid local LLM provider`.

## Run Migration On Branch DB

Run the migration directly against the branch DB:

```bash
cd apps/node_backend
zsh -lc 'set -a; source ../../.env.migration-test.local; set +a; npx tsx src/db/migrate.ts'
```

Verify the result with parameterized SQL so shell quoting does not corrupt string literals:

```bash
cd apps/node_backend
zsh -lc 'set -a; source ../../.env.migration-test.local; set +a; node --input-type=module - <<'"'"'NODE'"'"'
import { createClient } from "@libsql/client";
const client = createClient({ url: process.env.TURSO_DATABASE_URL, authToken: process.env.TURSO_AUTH_TOKEN });
async function scalar(sql, args = []) {
  const r = await client.execute({ sql, args });
  return Object.values(r.rows[0] ?? {})[0];
}
const tables = await client.execute({
  sql: "SELECT name FROM sqlite_schema WHERE name IN (?, ?) ORDER BY name",
  args: ["chat_channels", "chat_channel_names"],
});
const migrated = await scalar("SELECT COUNT(*) AS c FROM chat_channels");
const legacy = await scalar("SELECT COUNT(*) AS c FROM chat_channel_names");
const migration = await scalar("SELECT COUNT(*) AS c FROM migrations WHERE version = ?", ["025"]);
console.log(JSON.stringify({
  tables: tables.rows.map((r) => r.name),
  chatChannelsRows: migrated,
  legacyRows: legacy,
  migration025Rows: migration,
}, null, 2));
NODE'
```

Expected for the `chat_channels` migration:

- `chat_channels` exists.
- deprecated `chat_channel_names` still exists as rollback backup.
- row counts match immediately after migration.
- migration `025` is recorded once.

## Start Local App Against Branch DB

After migration validation, restart backend with migration disabled:

```bash
cd apps/node_backend
zsh -lc 'set -a; source ../../.env.migration-test.local; set +a; PORT=3010 AUTO_MIGRATE=false npm run dev'
```

Start Flutter Web:

```bash
cd apps/mobile_chat_app
zsh -lc 'set -a; source ../../.env.migration-test.local; set +a; PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter run \
  -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 8082 \
  --dart-define=BRICKS_API_BASE_URL=http://127.0.0.1:3010 \
  --dart-define=BRICKS_TEST_TOKEN="$BRICKS_TEST_TOKEN"'
```

Hand off:

- Frontend: `http://127.0.0.1:8082`
- Backend: `http://127.0.0.1:3010`
- DB: branch/test DB name
- `AUTO_MIGRATE=false` for running backend
- Quick Login writes as `FIXTURE_USER_ID`

## Smoke Checks

- Backend health: `curl -sS http://127.0.0.1:3010/api/health`
- Authenticated `/api/chat/channels` returns 200 and expected row count; do not print tokens.
- Channel create, rename, archive, refresh.
- Thread create, rename, archive, refresh.
- Existing historical message loading still works.
- `/api/chat/scopes` activity does not recreate hidden sidebar entities by itself.
