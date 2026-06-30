# Flutter Web Static Cache Headers

## Background

The Dokku preview deployed the latest commit, but browsers could still run an old Flutter Web bundle because `main.dart.js` was served with `Cache-Control: public, max-age=14400`.

## Goals

- Prevent preview and production browsers from keeping stale app shell JavaScript after deploys.
- Keep ordinary static files cacheable for a short period.
- Cover the cache policy in backend app tests.

## Implementation Plan

1. Add explicit static cache headers in the Express static file server.
2. Set `no-store, no-cache, must-revalidate, max-age=0` for unversioned Flutter app shell files and SPA fallback responses.
3. Keep non-shell static files on a short cache policy.
4. Add app-level tests for static cache headers.

## Acceptance Criteria

- `/`, `/main.dart.js`, `/flutter.js`, and SPA fallback paths return no-store/no-cache headers.
- Non-shell static assets return the short cache policy.
- Backend app tests and type-check pass.

## Validation Commands

- `cd apps/node_backend && npm test -- --run src/app.test.ts`
- `cd apps/node_backend && npm run type-check`
