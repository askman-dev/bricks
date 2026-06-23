---
name: bricks-local-cloud-dev
description: Start or explain the Bricks local manual development environment for UI/style/interaction work using a local Node backend, local Flutter Web frontend, cloud Turso data from .env.local, and Quick Login (Test) via BRICKS_TEST_TOKEN. Use when the user wants to edit code locally and inspect the real app with realistic cloud data, not when creating automated browser evidence.
---

# Bricks Local Cloud Development

Use this skill when the user wants to manually develop Bricks locally and inspect
styles, layout, interaction, navigation, or chat behavior against realistic cloud
data.

This is a manual development workflow, not the evidence harness. For automated
browser proof, use `evidence-driven-browser-test-env` instead.

## Safety Rules

- Never print, copy, commit, or summarize secret values from `.env.local`.
- It is OK to reference uncommitted local paths such as `.env.local`.
- When connecting a local backend to cloud Turso, force `AUTO_MIGRATE=false`.
- Do not write provider keys into cloud Turso for ordinary UI development.
- Prefer local env provider config, if needed: `LOCAL_LLM_CONFIG_ENABLED=true`
  with provider keys kept only in `.env.local`.
- Tell the user that rows written through Quick Login belong to `FIXTURE_USER_ID`,
  not necessarily their normal production login user.

## Expected Local Files

Read `.env.local` only as an environment source. Do not display its contents.

Required variables:

- `TURSO_DATABASE_URL`
- `TURSO_AUTH_TOKEN`
- `JWT_SECRET`
- `FIXTURE_USER_ID`
- `BRICKS_TEST_TOKEN`

Recommended variables:

- `PORT=3010`
- `BRICKS_API_BASE_URL=http://127.0.0.1:3010`
- `AUTO_MIGRATE=false`
- `BRICKS_LOCAL_DEV=true`
- `LOCAL_LLM_CONFIG_ENABLED=true` when testing real model replies from local env

## Startup Workflow

1. Check the branch and worktree first:

   ```bash
   git status --short --branch
   ```

2. Create or switch to the user's requested development branch. If they did not
   name one, create a short local branch from current `main`, for example:

   ```bash
   git switch -c dev/local-cloud-db-ui
   ```

3. Start the backend from `apps/node_backend`:

   ```bash
   set -a
   source ../../.env.local
   set +a
   PORT=3010 AUTO_MIGRATE=false npm run dev
   ```

   If the sandbox blocks `tsx` IPC or local server binding, rerun the same
   command with required escalation.

4. Start Flutter Web from `apps/mobile_chat_app`:

   ```bash
   set -a
   source ../../.env.local
   set +a
   PATH=/Users/admin/.local/tools/flutter/bin:$PATH flutter run \
     -d web-server \
     --web-hostname 127.0.0.1 \
     --web-port 8082 \
     --dart-define=BRICKS_API_BASE_URL=http://127.0.0.1:3010 \
     --dart-define=BRICKS_TEST_TOKEN="$BRICKS_TEST_TOKEN"
   ```

5. Give the user the frontend URL:

   ```text
   http://127.0.0.1:8082
   ```

## Verification Before Hand-Off

Before telling the user it is ready, verify:

- backend health:

  ```bash
  curl -sS http://127.0.0.1:3010/api/health
  ```

- Flutter Web printed a serving URL for `127.0.0.1:8082`.
- The login page should show `Quick Login (Test)` because
  `BRICKS_TEST_TOKEN` was injected as a Dart define.

If checking `/api/auth/me`, do not print the token. Use a command or script that
only reports HTTP status and whether a user object exists.

## Response Pattern

When the environment is running, answer with:

- current branch name
- frontend URL
- backend URL
- whether cloud Turso is in use
- `AUTO_MIGRATE=false` confirmation
- Quick Login availability
- any caveat about fixture user identity or expected write scope

Keep the response short. The user mainly needs the URL and safety state.

## Troubleshooting

- Backend `listen EPERM` for `tsx` IPC: rerun with escalation.
- `Quick Login (Test)` missing: confirm `BRICKS_TEST_TOKEN` was passed via
  `--dart-define`, then hot restart or restart Flutter Web.
- API calls hit production instead of local backend: confirm
  `BRICKS_API_BASE_URL=http://127.0.0.1:3010` was passed as a Dart define.
- DB writes are not visible in the user's normal production account: check
  `FIXTURE_USER_ID`; Quick Login writes as that fixture user.
- Migration concerns: stop and confirm `AUTO_MIGRATE=false` before continuing.
