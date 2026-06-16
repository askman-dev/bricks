# Local Chat Fixture Database

## Background

Chat scroll behavior needs a repeatable local environment that can load realistic
history without depending on GitHub OAuth or a live production database during
every test run. The production data source is Turso/libSQL, and the backend
already supports libSQL through `TURSO_DATABASE_URL`.

The local test environment should export a safe subset of chat-related data into
a local `file:` libSQL database, run the backend against that file, and provide a
test JWT for Flutter's existing `BRICKS_TEST_TOKEN` quick-login flow.

## Goals

- Build a local fixture database from a remote Turso database without storing
  remote credentials in the repository.
- Copy only the tables needed to render chat history, scopes, channel names, and
  related node/settings context.
- Provide a repeatable way to generate a dev JWT for a fixture user.
- Let Flutter Web load the local backend and use Quick Login instead of GitHub
  OAuth.
- Keep exported fixture files out of git.

## Implementation Plan

1. Add a backend script that exports a remote Turso/libSQL database subset into
   a local `file:` libSQL database.
2. Add a backend script that prints a local dev JWT for a selected fixture user.
3. Add package scripts for export and token generation.
4. Document the local startup flow with environment variables, backend command,
   Flutter command, and quick-login usage.
5. Validate that the exported local DB can answer chat history endpoints through
   the normal backend code path.

## Acceptance Criteria

- The export command reads remote credentials only from environment variables.
- The export command writes a local DB file under a gitignored cache path.
- The export command does not copy API config secrets by default.
- The local backend can run with `TURSO_DATABASE_URL=file:<fixture-db>`.
- The token generation command emits a JWT for the selected fixture user using
  the local `JWT_SECRET`.
- Flutter can be launched with `BRICKS_TEST_TOKEN` and `BRICKS_API_BASE_URL`
  defines and can enter the app through Quick Login.

## Validation Commands

- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test`
- `cd apps/mobile_chat_app && flutter analyze`
