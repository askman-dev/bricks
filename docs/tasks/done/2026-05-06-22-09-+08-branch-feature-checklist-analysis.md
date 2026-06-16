# Branch Feature Checklist Analysis

## Background

The current branch needs to be compared with `main` to identify the planned feature scope, determine which implementation pieces already exist, and list the remaining work.

## Goals

- Read branch-added plan files and summarize the intended feature scope.
- Compare branch changes against `main`.
- Map planned acceptance criteria to current code and tests.
- Produce a checklist of completed and remaining work without changing feature behavior.

## Implementation Plan

1. Fetch `origin/main`, then compare `origin/main...HEAD` to identify changed files and branch-added plans.
2. Read the added plan files under `docs/tasks/done/`.
3. Inspect backend, Flutter, migration, test, and code-map diffs.
4. Report completed, partial, missing, and risky items with concrete file references.

## Acceptance Criteria

- The analysis identifies all branch-added plan files.
- The checklist separates completed work from remaining work.
- The checklist calls out implementation risks where code behavior does not meet the plan.
- No product behavior is changed by this analysis task.

## Validation Commands

- `git fetch origin main`
- `git diff --name-status origin/main...HEAD`
- `git diff --stat origin/main...HEAD`
