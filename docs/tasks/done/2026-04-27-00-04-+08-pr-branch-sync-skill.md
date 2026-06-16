# PR Branch Sync Skill

## Background
Recent PR work exposed a repeatable workflow: push can fail because network access is restricted or because the remote branch changed after the local branch was created. Codex should preserve remote work, check whether a PR already exists, rebase local changes when the remote branch is newer, push again, and update the PR summary.

## Goals
- Add a repository-local Codex skill under `.codex/skills/`.
- Capture the PR branch recovery workflow concisely.
- Emphasize preserving remote commits and using `--force-with-lease` only when intentionally rewriting a branch.

## Implementation Plan (phased)
1. Create `.codex/skills/github-pr-branch-sync/SKILL.md`.
2. Document checks for current branch, existing PR, remote branch existence, and remote-ahead state.
3. Document safe rebase, push, and PR summary update steps.
4. Validate the skill metadata and markdown content by inspecting the created file.

## Acceptance Criteria
- A new Codex skill exists under `.codex/skills/github-pr-branch-sync/`.
- The skill tells Codex what to do after a failed push.
- The skill includes checks for existing PRs and remote branches.
- The skill instructs Codex to rebase local changes when the remote branch is newer.
- The skill instructs Codex to update the PR summary after pushing.
