# Background
The previous implementation delivered a working review-thread resolver skill using Python, but current requirements explicitly forbid Python and prefer repository-native stacks (Dart or shell script).

# Goals
- Replace the Python implementation with a non-Python implementation.
- Keep existing functionality: list review threads, filter by mode, support dry-run, resolve via GraphQL mutation.
- Update skill documentation to reference the new script entrypoint.

# Implementation Plan (phased)
## Phase 1: Replace runtime implementation
- Remove the Python script from the skill.
- Add a shell script implementation using `curl` + `jq` for GraphQL query/mutation.

## Phase 2: Update skill docs
- Update `SKILL.md` command examples to use the new shell script.
- Keep mode semantics and safety guidance aligned with previous behavior.

## Phase 3: Validate behavior
- Run dry-run checks against PR #89 in `outdated` and `unresolved` modes.
- Run shell syntax check (`bash -n`).

# Acceptance Criteria
- No Python script is required by the skill.
- The replacement script supports modes: `outdated`, `unresolved`, `all` and `--dry-run`.
- Dry-run output reports selected threads without mutation.
- Live mode issues `resolveReviewThread` for selected thread IDs.
