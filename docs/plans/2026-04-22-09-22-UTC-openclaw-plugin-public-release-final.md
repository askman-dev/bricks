# OpenClaw plugin public release final plan

## Background

`apps/node_openclaw_plugin` is being prepared for external distribution to
OpenClaw users. Product decisions are finalized:

- Distribution target: npm + ClawHub
- Canonical OpenClaw plugin id remains: `dev-askman-bricks`
- npm package name for public install: `@askman-dev/bricks-openclaw-plugin`
- Final registry publication is a manual operator step (no auto publish)

The plugin should be installable through standard OpenClaw package flow without
requiring repository cloning.

## Goals

1. Keep package metadata in a publishable state for npm + ClawHub.
2. Keep OpenClaw runtime metadata aligned to built `dist/*` entrypoints for
   packaged installs.
3. Keep release-facing documentation aligned to the final public package name
   and external install/config/update flow.
4. Keep release validation commands and manual publish handoff explicit.

## Implementation Plan (phased)

### Phase 1: Public package metadata and identity

- Ensure `apps/node_openclaw_plugin/package.json` stays public publishable:
  - package name `@askman-dev/bricks-openclaw-plugin`
  - no `private: true`
  - release metadata (`license`, `repository`, `homepage`, `bugs`, `keywords`)
  - packaging controls (`files`, `exports`)
- Keep `apps/node_openclaw_plugin/package-lock.json` root package identity
  consistent with `package.json`.

### Phase 2: OpenClaw packaged-install metadata

- Preserve plugin/channel identity as `dev-askman-bricks`.
- Keep OpenClaw metadata pointing to built runtime outputs (`dist/*`).
- Keep packaged install preference (`openclaw.install.defaultChoice=package`).
- Preserve native plugin manifest inclusion (`openclaw.plugin.json`) in package
  artifact.

### Phase 3: External-user documentation

- Keep `apps/node_openclaw_plugin/README.md` aligned to public package flow:
  - install: `openclaw plugins install @askman-dev/bricks-openclaw-plugin`
  - onboarding/configure steps
  - update flow
  - troubleshooting notes
  - clear separation from local dev-only install workflow

### Phase 4: Validation and artifact inspection

Run and record:

- `cd apps/node_openclaw_plugin && npm test`
- `cd apps/node_openclaw_plugin && npm run type-check`
- `cd apps/node_openclaw_plugin && npm run build`
- `cd apps/node_openclaw_plugin && npm pack`
- inspect tarball contents and confirm:
  - `dist/*`
  - `openclaw.plugin.json`
  - `package.json`
  - `README.md`

### Phase 5: Manual operator handoff (explicit)

Do not auto-publish from agent flow. Human operator runs:

- npm publish:
  - `cd apps/node_openclaw_plugin && npm publish --access public`
- ClawHub publish:
  - `clawhub package publish apps/node_openclaw_plugin --dry-run`
  - `clawhub package publish apps/node_openclaw_plugin`
- clean-install verification:
  - `openclaw plugins install @askman-dev/bricks-openclaw-plugin`
  - `openclaw plugins inspect dev-askman-bricks`
  - `openclaw configure`
  - `openclaw gateway restart`
  - `openclaw plugins update dev-askman-bricks`

## Acceptance Criteria

- Public package identity is finalized as
  `@askman-dev/bricks-openclaw-plugin`.
- Plugin id remains `dev-askman-bricks`.
- Packaged artifact includes built runtime files and plugin manifest.
- README/install commands match the final public package name.
- Manual npm + ClawHub publication and clean-install verification commands are
  explicitly documented.
