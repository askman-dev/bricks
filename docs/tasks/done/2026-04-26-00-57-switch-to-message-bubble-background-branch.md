## Background

The repository needs to be synced with the latest remote `main`, and the existing remote branch for message bubble color changes needs to be identified and checked out locally.

## Goals

- Refresh remote refs from `origin`.
- Update local `main` to match `origin/main` without overwriting unrelated local changes.
- Find the remote branch associated with message bubble color changes.
- Switch the workspace to that branch with proper tracking.

## Implementation Plan

### Phase 1

Fetch and prune remote refs from `origin` to ensure the branch list and `main` pointer are current.

### Phase 2

Identify the message bubble color branch by searching remote branch names and commit subjects, then confirm the intended branch.

### Phase 3

Checkout local `main`, fast-forward it to `origin/main`, and switch to the identified remote branch with tracking.

## Acceptance Criteria

- `origin/main` is fetched and local `main` is fast-forwarded to it.
- The remote bubble color branch is identified.
- The current checked-out branch is the local tracking branch for the bubble color change.
- Validation commands:
  - `git fetch --all --prune`
  - `git status --short --branch`
  - `git branch -vv`
