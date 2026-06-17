# Background
GitHub Actions is deprecating Node.js 20 for JavaScript-based actions and will default to Node.js 24 starting June 2, 2026. This repository still references `actions/checkout@v4` in multiple workflow files.

# Goals
- Replace deprecated `actions/checkout@v4` usage with a Node.js 24-compatible release.
- Keep workflow behavior unchanged outside of the action version bump.
- Validate workflow references after the update.

# Implementation Plan (phased)
## Phase 1: Locate deprecated action references
- Scan `.github/workflows` for `actions/checkout@v4` and record impacted files.

## Phase 2: Update action versions
- Replace each `actions/checkout@v4` reference with `actions/checkout@v5` in workflow YAML files.
- Leave already-updated or SHA-pinned modern references unchanged.

## Phase 3: Validate
- Re-scan workflows to ensure no `actions/checkout@v4` references remain.
- Run `git diff --stat` for a concise change summary.

# Acceptance Criteria
- No workflow file under `.github/workflows` contains `actions/checkout@v4`.
- Updated workflows use `actions/checkout@v5` where `v4` was previously used.
- A repository scan confirms all deprecated references were removed.
