# Thread Auto Name Source Evidence Case

## Requirement

When a user sends the first message in a non-main Thread, the backend should
give that Thread a usable display name without requiring an extra frontend
request:

1. Insert `first_message_exact` immediately from the first user message when no
   Thread name exists.
2. After the assistant reply completes, claim one generated-name attempt.
3. Replace the exact name with `first_message_generated` only if the row is
   still `first_message_exact`.
4. Never run the generated-name attempt more than once for the same Thread.

## Baseline Behavior To Prove

Before a respond request, the case-specific `channelId + threadId` must have no
name row in `/api/chat/channel-names`.

## Fixed Behavior To Prove

After the first respond request completes, using API for the user action and DB
checks for low-request evidence:

- the Thread has a name row
- `source` is `first_message_generated`
- `generatedNameAttemptedAt` is non-null
- the final display name differs from the raw first message when the configured
  model generates a better title

After a second respond request in the same Thread:

- `generatedNameAttemptedAt` is unchanged
- the display name is unchanged
- `source` remains `first_message_generated`

## Fixture/Data Shape

The harness creates a unique channel/thread pair per run:

- `channelId`: `e2e-auto-name-<run-id>`
- `threadId`: `thread-<run-id>`
- `sessionId`: `session:<channelId>:<threadId>`

The test user is `FIXTURE_USER_ID`, authenticated by `BRICKS_TEST_TOKEN`.

## Required Environment Variables

Loaded from repo-root `.env.local`:

- `BRICKS_TEST_TOKEN`
- `FIXTURE_USER_ID`
- `JWT_SECRET`
- database configuration used by the local backend
- local LLM configuration or persisted user LLM config

Optional:

- `BRICKS_API_BASE_URL` defaults to `http://127.0.0.1:3011`
- `PORT` defaults to `3011`
- `KEEP_SERVICES=1` keeps a backend started by this harness running
- `RUN_MIGRATIONS=1` applies pending migrations before the flow

## Run Command

```sh
tools/evidence/thread_auto_name_source/run.sh
```

## Evidence Output

Evidence is written under:

```text
.cache/evidence/thread-auto-name-source/<YYYYmmdd-HHMMSS>/
```

Expected files:

- `summary.json`
- `<run-id>-auth-me.json`
- `<run-id>-names-before.json`
- `<run-id>-respond-first.json`
- `<run-id>-names-after-first.json`
- `<run-id>-respond-second.json`
- `<run-id>-names-after-second.json`
- optional backend/migration logs

## Checkpoints

- `authMe`: test token resolves to the expected fixture user.
- `backendReady`: local backend responds on `/api/health`.
- `baselineNoName`: the generated fixture Thread has no name row before the flow.
- `firstRespondAccepted`: `/api/chat/respond` accepts the first message.
- `generatedNameVisible`: `/api/chat/channel-names` shows `first_message_generated`.
- `secondRespondAccepted`: a second message is accepted in the same Thread.
- `generationRunsOnce`: source/name/attempt timestamp do not change after the second message.

## Failure Reading Notes

- If `authMe` fails, check `BRICKS_TEST_TOKEN`, `JWT_SECRET`, and `FIXTURE_USER_ID`.
- If `generatedNameVisible` stays at `first_message_exact`, inspect backend logs
  for local LLM config or provider errors.
- If `generationRunsOnce` fails, the generated attempt claim is not guarded
  tightly enough.
- The harness intentionally checks the name row through the database instead of
  repeatedly polling `/api/chat/channel-names`, so it does not create false 429
  failures while validating the user-visible API flow.
