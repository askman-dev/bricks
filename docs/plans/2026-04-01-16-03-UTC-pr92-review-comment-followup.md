# Background
PR #92 received Copilot review comments covering shell argument parsing, runtime dependency checks, GraphQL error handling, package manager safety/privilege behavior, and skill documentation clarity.

# Goals
- Address valid review findings in code and skill docs.
- Keep bash-based implementation (non-Python) while improving robustness.
- Resolve review threads after fixes are in place.

# Implementation Plan (phased)
## Phase 1: Fix `resolve_review_threads.sh`
- Validate `--mode` has a non-empty value before shifting.
- Add explicit `curl` dependency check.
- Harden `graphql_call` with `curl -fsS` and JSON validation.

## Phase 2: Fix `tools/init_dev_env.sh`
- Handle package installs with root/sudo/doas fallback.
- Improve error guidance when privilege escalation is unavailable.
- Switch pacman install path to `-Syu` to avoid partial-upgrade pattern.

## Phase 3: Docs alignment
- Update skill prerequisites to mention both `jq` and `curl`.
- Clarify script is bash-based in skill docs.

## Phase 4: Validate + resolve threads
- Run syntax checks and dry-run command checks.
- Resolve addressed review threads on PR #92.

# Acceptance Criteria
- All actionable PR #92 review comments are addressed in code/docs.
- Script behavior is more robust for missing args and API failures.
- Init script install behavior handles non-root environments safely.
- Review threads are resolved after updates.
