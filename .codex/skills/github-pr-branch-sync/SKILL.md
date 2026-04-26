---
name: github-pr-branch-sync
description: Recover and update an existing GitHub PR branch when push fails, the remote branch may already exist, or the remote branch is newer than the local branch. Use when Codex is pushing PR work and needs to check existing PRs, preserve remote commits, rebase local changes, push safely, and update the PR summary/body.
---

# GitHub PR Branch Sync

Use this when a branch push fails, a PR may already exist, or the remote PR branch has changed since the local branch was created.

## Core workflow

1. Identify the local branch and status:
   ```bash
   git status --short --branch
   git log -3 --oneline --decorate
   ```

2. Check whether a PR already exists for the branch:
   ```bash
   gh pr view --head <branch>
   ```
   If that fails, check the list:
   ```bash
   gh pr list --head <branch> --state open
   ```

3. Check whether the remote branch exists and update local remote-tracking metadata:
   ```bash
   git ls-remote --heads origin <branch>
   git fetch origin <branch>
   ```

4. Compare local and remote before pushing:
   ```bash
   git log --oneline --left-right --cherry-pick HEAD...origin/<branch>
   ```
   - Left-only commits (`<`) are local-only.
   - Right-only commits (`>`) are remote-only.

5. If the remote branch has commits that local does not, preserve them:
   ```bash
   git rebase origin/<branch>
   ```
   Resolve conflicts by keeping the intended local changes while preserving remote commits. After resolving files:
   ```bash
   git add <resolved-files>
   GIT_EDITOR=true git rebase --continue
   ```

6. Push after the branch is based on the latest remote:
   ```bash
   git push
   ```

7. If the push is rejected as stale after an intentional local history rewrite:
   - Run `git fetch origin <branch>`.
   - Inspect the new remote commits with `git log --oneline --left-right --cherry-pick HEAD...origin/<branch>`.
   - Rebase if remote has new work.
   - Use `git push --force-with-lease` only after verifying that no remote work will be discarded.

8. After a successful push, update the existing PR summary/body:
   ```bash
   gh pr edit <pr-number> --body "<updated summary>"
   ```
   The summary should mention:
   - What changed.
   - Validation commands and results.
   - Whether code maps were updated, or why they were not.

## Safety rules

- Never overwrite remote branch commits blindly.
- Prefer `git push` after rebasing onto the remote branch.
- Use `--force-with-lease`, not `--force`, and only when rewriting PR branch history is intentional.
- If a PR already exists, update it instead of creating a duplicate PR.
- If GitHub API/network commands fail due to restricted network access, rerun the same command with the required escalation rather than switching workflows.
