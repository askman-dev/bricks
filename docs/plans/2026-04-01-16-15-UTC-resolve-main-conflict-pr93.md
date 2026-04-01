# Background
PR #93 reported merge conflicts with `main` across chat, backend LLM, and agent runtime contract files.

# Goals
- Resolve merge conflicts cleanly so the branch is mergeable.
- Preserve the latest session-config/backend-routing fixes while completing the merge.
- Validate the merged tree for analysis/test sanity.

# Implementation Plan (phased)
1. Merge `origin/main` into the working branch.
2. Resolve conflicted files with consistent code for chat screen, backend LLM routes/service/types, and agent settings/runtime gateway.
3. Run Flutter analyze and package tests.
4. Commit the merge resolution.

# Acceptance Criteria
- `git status` shows no unresolved conflicts.
- Branch contains a merge commit integrating `origin/main`.
- Core checks pass for affected app/package scope.
