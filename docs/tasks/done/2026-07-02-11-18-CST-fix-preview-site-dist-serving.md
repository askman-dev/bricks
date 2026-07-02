# Fix Preview Site Dist Serving

## Background

A preview public site URL returned `Internal server error` because the database marked the site build as succeeded while `web/dist/index.html` was missing from the shared sandbox root. After rebuilding the site, the path-based preview also needed relative Vite assets so `/sites/<slug>` URLs load generated JS/CSS from the site route instead of the Bricks app root.

## Goals

- Restore the affected preview public site URL.
- Generate relative Vite assets for new starter workspaces.
- Return a controlled not-published response when a succeeded build record points to a missing dist index.

## Acceptance Criteria

- The affected preview URL returns HTML with relative asset paths.
- The generated JS and CSS asset URLs under `/sites/<slug>/assets/` return 200.
- Missing `web/dist/index.html` does not produce a JSON 500 response.

## Validation

- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/routes/channelSiteHost.test.ts src/services/channelSiteService.test.ts src/services/userSandboxService.test.ts`
- `DOCS_URL=https://craft.bricks.cool npm run build` from `apps/docs_site`
- `curl -fsS https://codex-channel-react-site-workspace-preview-838eb19a.craft-dev.bricks.cool/sites/s-d1893c434ca7`
- `curl -I https://codex-channel-react-site-workspace-preview-838eb19a.craft-dev.bricks.cool/sites/s-d1893c434ca7/assets/index-SL9ysTrS.js`
- `curl -I https://codex-channel-react-site-workspace-preview-838eb19a.craft-dev.bricks.cool/sites/s-d1893c434ca7/assets/index-DFbQ8j6l.css`

## Deployment Evidence

- The affected workspace `package.json` was updated to build with `vite build --base ./ --outDir ../web/dist-next --emptyOutDir`.
- The affected preview site was rebuilt and published to shared `web/dist`.
- The preview site HTML now references `./assets/...`, and generated JS/CSS assets under `/sites/s-d1893c434ca7/assets/` return HTTP 200.
