# Background
The repository has two GitHub workflows related to pull request review automation. The `pr_review_thread_auto_resolver.yml` workflow resolves outdated review threads automatically, but it currently does not leave a human-visible comment after successful resolution. Maintainers want explicit visibility when the automation runs and resolves threads, while avoiding noise when no action is taken.

# Goals
1. Update the auto resolver workflow so it posts an English PR comment when it successfully resolves one or more review threads.
2. Ensure the comment clearly indicates that the resolutions were performed by automation (robot) using the same personal token that performs the resolve mutations.
3. Ensure no comment is posted when the workflow executes but resolves zero threads.

# Implementation Plan (phased)
## Phase 1: Review current resolver output contract
- Read `.github/workflows/pr_review_thread_auto_resolver.yml` and the resolver script used by the workflow.
- Confirm what structured output is available for detecting resolved count and listing resolved thread references.

## Phase 2: Extend workflow with parse + conditional comment
- Capture resolver script output to a log file while keeping console output.
- Parse:
  - `resolved_threads=<n>` for resolved count.
  - Per-thread lines for `url=` values to surface links to threads resolved by automation.
- Expose parsed values via step outputs.
- Add a conditional `actions/github-script` step that posts a PR comment only when resolved count is greater than zero.
- Use `${{ secrets.GH_TOKEN }}` for that comment action to match the token used for thread resolution.

## Phase 3: Validate syntax and summarize
- Run YAML lint/inspection check (or targeted sanity check command) to verify workflow file integrity.
- Review diff and ensure behavior matches requirements: comment only on actual resolution actions.

# Acceptance Criteria
- On runs where at least one review thread is resolved, a PR comment is added in English and includes:
  - confirmation that auto resolver succeeded,
  - explicit note that resolved status was set by automation,
  - references to resolved thread comment URLs when available.
- On runs where zero threads are resolved, no PR comment is created.
- Comment creation uses `${{ secrets.GH_TOKEN }}` (same token identity used for resolve actions).
- Workflow remains valid and runnable in GitHub Actions.
