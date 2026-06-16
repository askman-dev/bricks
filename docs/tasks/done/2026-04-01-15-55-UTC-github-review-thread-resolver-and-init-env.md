# Background
We introduced a GitHub PR review-thread resolver skill to support REVIEW_FIXED workflows and avoid redundant Copilot trigger comments. During iteration we also aligned implementation with repository constraints (no Python) and improved environment bootstrap so required CLI dependencies are prepared automatically.

# Goals
- Provide a reusable skill that can resolve GitHub PR review threads safely.
- Use repository-native tooling (shell script with `curl` + `jq`) instead of Python.
- Ensure bootstrap (`tools/init_dev_env.sh`) installs or validates required commands (`curl`, `jq`) instead of failing late.
- Keep operations auditable via dry-run-first workflow.

# Implementation Plan (phased)
## Phase 1: Validate GitHub review-thread API behavior
- Query review threads and inspect `id`, `isResolved`, `isOutdated`.
- Validate thread resolution flow via GraphQL mutations (`resolveReviewThread`, and reversibility checks where needed).

## Phase 2: Implement reusable skill (shell)
- Create `.codex/skills/github-pr-review-thread-resolver/`.
- Add executable script using `curl` + `jq` to:
  - page `reviewThreads`,
  - filter by mode (`outdated`, `unresolved`, `all`),
  - support `--dry-run`,
  - resolve selected thread IDs.
- Document usage, safety constraints, and token requirements in `SKILL.md`.

## Phase 3: Bootstrap dependency hardening
- Update `tools/init_dev_env.sh` to handle `curl`/`jq` as required dependencies.
- Add package-manager detection and automatic installation attempts (`apt-get`, `dnf`, `yum`, `apk`, `pacman`, `brew`).
- Keep explicit manual remediation guidance when auto-install is not possible.

## Phase 4: Validation and rollout checks
- Run syntax checks for changed shell scripts.
- Execute resolver script in dry-run mode on a real PR for selection visibility.
- Verify init script help output and command-flow integrity.

# Acceptance Criteria
- A single local skill exists for review-thread resolution in REVIEW_FIXED workflows.
- Skill implementation uses shell tooling only (no Python runtime dependency).
- Resolver supports `--dry-run` and mode-based selection with clear summary output.
- `init_dev_env.sh` proactively attempts to install missing `curl`/`jq` and only fails with actionable guidance if installation cannot be completed.
- Documentation and operational steps are consolidated in one plan file for this change stream.
