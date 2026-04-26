# Background
The repository currently deploys Flutter Web from `apps/mobile_chat_app/build/web` on Vercel, while the Docusaurus docs site is configured at root (`baseUrl: '/'`). We need to mount docs at `/docs/` without breaking existing Flutter SPA routing or API rewrites.

# Goals
1. Configure Docusaurus so generated links and assets are rooted at `/docs/`.
2. Update Vercel build flow to package docs output under Flutter Web output at `build/web/docs`.
3. Update Vercel rewrites so `/docs` and `/docs/*` are served by Docusaurus, while all other app routes continue to Flutter SPA.
4. Keep API routing (`/api/*`) unchanged.

# Implementation Plan (phased)
## Phase 1: Docs site config
- Update `apps/docs_site/docusaurus.config.ts`:
  - Set `baseUrl` to `process.env.DOCS_BASE_URL ?? '/docs/'`.
  - Keep `routeBasePath: '/'` to preserve docs-only mode semantics.
  - Add clarifying comments to avoid setting `/docs` in `DOCS_URL`.

## Phase 2: Build pipeline integration
- Update `tools/vercel-build.sh`:
  - Add `install_docs_site` and `build_docs_site` helpers.
  - Run docs dependency install in `--install-only` mode.
  - After Flutter web release build, build docs and copy to `apps/mobile_chat_app/build/web/docs`.
  - Ensure copy happens after Flutter build to avoid output overwrite.

## Phase 3: Vercel route dispatch
- Update `vercel.json` rewrites:
  - Keep `/api/:path* -> /api/index` first.
  - Add `/docs -> /docs/index.html` and `/docs/:path* -> /docs/index.html` before Flutter fallback.
  - Keep catch-all fallback to `/index.html` last.

## Phase 4: Regression metadata
- Review and update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` if docs entry/routing capabilities are impacted.

# Acceptance Criteria
1. Running Docusaurus build with `DOCS_BASE_URL=/docs/` generates docs site paths under `/docs/`.
2. Running `bash ./tools/vercel-build.sh` produces `apps/mobile_chat_app/build/web/docs/index.html`.
3. `vercel.json` rewrites route `/docs` and `/docs/*` to docs index before Flutter fallback.
4. Existing `/api/*` and Flutter fallback routing remain present and ordered correctly.
