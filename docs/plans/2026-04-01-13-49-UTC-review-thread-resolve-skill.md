# Background
We need a reliable method to mark GitHub pull request review threads as resolved for workflows where review findings are fixed or outdated. Existing local skills can trigger Copilot review comments, but there is no local skill dedicated to resolving review threads.

# Goals
- Validate the exact GitHub API operation that marks a review thread as resolved.
- Provide a reusable local Codex skill that can resolve outdated and/or unresolved review threads on a target PR.
- Include a safe dry-run mode and explicit reporting for auditability.

# Implementation Plan (phased)
## Phase 1: Validate API behavior on a real PR
- Query PR review threads via GitHub GraphQL and inspect `id`, `isResolved`, and `isOutdated`.
- Execute `resolveReviewThread` mutation on a known thread to verify behavior.
- Execute `unresolveReviewThread` mutation to confirm reversibility.

## Phase 2: Add reusable skill
- Create a new skill directory under `.codex/skills/`.
- Add a script that:
  - lists review threads,
  - filters by mode (`outdated`, `unresolved`, `all`),
  - resolves selected threads via GraphQL mutation,
  - supports dry-run.
- Add `SKILL.md` describing when and how to use the script.

## Phase 3: Validate locally
- Run script in dry-run mode against PR #89.
- Run skill validation checks (if available for this repo) and shell syntax checks.

# Acceptance Criteria
- A documented method exists and is demonstrated for resolving PR review threads using GitHub GraphQL.
- A new skill exists with executable script and usage instructions.
- Dry-run output clearly reports total threads and threads selected for resolution.
- Live mode can resolve target threads when token permissions allow.
