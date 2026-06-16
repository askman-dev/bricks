# OpenClaw plugin publish plan

## Background

The Bricks OpenClaw plugin currently works as an in-repo local plugin under
`apps/node_openclaw_plugin`, but the goal is to publish it for external
OpenClaw users.

OpenClaw community plugin discovery works through:

- `openclaw plugins install <package>` with **ClawHub first, then npm**
- explicit ClawHub installs via `openclaw plugins install clawhub:<package>`
- local path / linked installs for development only

ClawHub is the canonical community discovery surface for OpenClaw plugins, but
npm is also a supported install source and automatic fallback.

## Goals

- Make the Bricks plugin installable by outside OpenClaw users with a single
  command.
- Decide the publish path: npm only vs npm + ClawHub.
- Close the packaging gaps between the current repo-local plugin package and a
  real public plugin release.
- Validate the published artifact from a fresh OpenClaw install flow.

## Implementation Plan

### Phase 1: Decide the public distribution target

- Prefer **npm + ClawHub**:
  - npm provides a standard public package artifact
  - ClawHub improves discoverability and is the canonical community listing
- Pick the final public package name and plugin branding.
- Confirm whether the public plugin id stays `dev-askman-bricks` or should be
  renamed before first public release.

### Phase 2: Make the package publishable

- Remove `private: true` from `apps/node_openclaw_plugin/package.json`.
- Add public release metadata if missing:
  - `license`
  - `repository`
  - `homepage`
  - `bugs`
  - optional `keywords`
- Ensure the npm tarball includes built runtime files and manifest files.
- Add/verify `openclaw` package metadata required for packaged plugin
  distribution, especially:
  - built runtime entrypoints
  - compatibility metadata for ClawHub / packaged plugin validation
- Review whether repo-local-only install hints such as `openclaw.install.localPath`
  should remain, be adjusted, or be removed for the public package.

### Phase 3: Make the artifact release-safe

- Ensure `npm run build` produces the files referenced by package metadata.
- Run plugin validation:
  - `cd apps/node_openclaw_plugin && npm test`
  - `cd apps/node_openclaw_plugin && npm run type-check`
  - `cd apps/node_openclaw_plugin && npm run build`
- Run a local package dry run:
  - `npm pack`
- Inspect the tarball contents to confirm `dist/*`, `openclaw.plugin.json`, and
  package metadata are present.

### Phase 4: Publish

- Publish to npm first:
  - `npm publish --access public`
- Publish to ClawHub after npm or directly from source using:
  - `clawhub package publish <source>`
  - use `--dry-run` first
- Keep the GitHub repo public and link it from the package metadata/docs.

### Phase 5: Verify the real external-user flow

- In a clean OpenClaw profile or clean machine, test:
  - `openclaw plugins install <package-name>`
  - `openclaw plugins inspect <plugin-id>`
  - `openclaw plugins enable <plugin-id>` if needed
  - `openclaw configure` / channel onboarding for the Bricks config
- Confirm gateway startup and plugin load behavior from logs.
- Confirm the plugin can be updated later via:
  - `openclaw plugins update <plugin-id>`

## Acceptance Criteria

- External users can install the plugin without cloning this repository.
- `openclaw plugins install <package-name>` works from a clean environment.
- The published artifact contains built runtime files and valid OpenClaw plugin
  metadata.
- The plugin is discoverable at least on npm, and ideally also on ClawHub.
