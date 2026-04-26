# Background

The previous implementation created the Docusaurus project at repository root (`website/`), but stakeholder feedback requires the docs site to live under `apps/`.

# Goals

1. Relocate the Docusaurus project from `website/` to `apps/docs_site/`.
2. Keep the site functional with docs sourced from repository root `docs/`.
3. Update README run/build instructions to the new location.

# Implementation Plan (phased)

## Phase 1: Relocation
- Move `website/` to `apps/docs_site/` with full history-preserving rename.

## Phase 2: Configuration fixes
- Update Docusaurus docs source path for new directory depth (`../../docs`).
- Update README commands to run from `apps/docs_site`.

## Phase 3: Validation
- Run `npm install` and `npm run build` from `apps/docs_site`.
- Verify changed file scope with `git diff --name-status`.

# Acceptance Criteria

1. No `website/` remains at repo root.
2. `apps/docs_site` contains runnable Docusaurus project.
3. `cd apps/docs_site && npm run build` succeeds.
4. README points to the new docs site location.
