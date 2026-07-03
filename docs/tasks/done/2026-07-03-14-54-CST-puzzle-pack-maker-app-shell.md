# Puzzle Pack Maker App Shell

## Background

Puzzle Pack Maker is a new iOS-first app that will eventually ship independently from the Bricks chat app. During the first stage it lives in the Bricks monorepo so it can reuse the existing backend, GitHub OAuth flow, deployment host, and local development workflow.

The app must be deployed under the existing Bricks domain at `https://craft.bricks.cool/puzzle-pack-maker`, while the root Bricks app remains available at `https://craft.bricks.cool`.

## Goals

- Add a separate Flutter app named `puzzle_pack_maker`.
- Preserve GitHub login through the existing Bricks backend OAuth flow.
- Use an independent native callback scheme for future iOS release separation.
- Show a simple authenticated three-tab Hello World shell after login.
- Serve the web build from `/puzzle-pack-maker` under the same backend/static host.
- Keep the app boundary clean enough to move to a separate repository later.

## Implementation Plan

1. Scaffold `apps/puzzle_pack_maker` as an independent Flutter app with iOS and Web targets.
2. Add app-local auth/OAuth helpers copied from the proven Bricks flow, adjusted to use `puzzlepackmaker://auth/github/callback` for native login and same-origin `/api/auth/github` for web login.
3. Build a startup router that sends logged-out users to GitHub login and logged-in users to a three-tab `Create`, `Gallery`, and `Library` shell.
4. Update backend OAuth return target validation to allow the new native callback scheme.
5. Update deployment/build paths so the main static root includes `puzzle-pack-maker/` with a Flutter web build using `--base-href /puzzle-pack-maker/`.
6. Update code maps to include the new app entry point, auth route, deployment path, and regression risks.

## Acceptance Criteria

- Visiting `/puzzle-pack-maker` loads the Puzzle Pack Maker Flutter web app instead of the root Bricks chat app.
- A logged-out user sees a Puzzle Pack Maker GitHub login screen.
- A logged-in user sees a bottom navigation app with three tabs.
- The three tabs show Hello World content for Create, Gallery, and Library.
- Web GitHub login redirects through `/api/auth/github` and returns to the current `/puzzle-pack-maker` page.
- Native iOS GitHub login uses `puzzlepackmaker://auth/github/callback`.
- Existing Bricks root web app and existing `bricks://auth/github/callback` login behavior remain supported.
- Code maps include the new app shell and auth/deployment impact.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/puzzle_pack_maker && flutter test`
- `cd apps/puzzle_pack_maker && flutter build web --release --base-href /puzzle-pack-maker/`
- `cd apps/node_backend && npm test -- --run src/routes/auth.test.ts src/app.test.ts`
- `cd apps/node_backend && npm run type-check`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null`
