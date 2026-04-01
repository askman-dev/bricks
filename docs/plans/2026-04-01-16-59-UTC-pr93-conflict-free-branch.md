# Background
PR #93 branch has merge conflicts against the current `main` branch, so a conflict-free replacement branch is needed.

# Goals
- Recreate the PR #93 feature changes on top of the latest `origin/main`.
- Resolve conflicts once in a clean linear history.
- Publish a new branch that can be used to open a fresh no-conflict PR.

# Implementation Plan (phased)
1. Fetch remote refs and inspect PR #93 commit history.
2. Create a new branch from `origin/main`.
3. Cherry-pick the feature commits from PR #93 (excluding merge commits) and resolve any conflicts.
4. Run targeted tests/checks for changed areas.
5. Commit any conflict-resolution adjustments and push the new branch.

# Acceptance Criteria
- A new branch exists on remote containing PR #93 functionality.
- `git status` is clean and branch is based on latest `origin/main`.
- Relevant tests for the touched package(s) complete successfully.
- New branch can be used to open a PR without conflicts.
