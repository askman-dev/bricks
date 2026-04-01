# Background
The new review-thread resolver skill depends on command-line tools (`curl`, `jq`). The repository bootstrap script should verify these dependencies so Codex/local runs fail fast with clear remediation hints.

# Goals
- Update `tools/init_dev_env.sh` to check for `curl` and `jq` explicitly.
- Keep startup UX clear by adding actionable install hints.
- Reflect dependency expectations in environment notes.

# Implementation Plan (phased)
## Phase 1: Add dependency checks
- Add `ensure_cmd` calls for `curl` and `jq` in `main` before tool-dependent workflows run.
- Provide concise install guidance in error messages.

## Phase 2: Update guidance output
- Add a note in the completion section that `jq` is required by GitHub automation skills.

## Phase 3: Validate
- Run `bash -n tools/init_dev_env.sh`.
- Run `tools/init_dev_env.sh --help` to ensure help text and argument handling still work.

# Acceptance Criteria
- `init_dev_env.sh` fails early if `curl` or `jq` is missing.
- Error messages include remediation hints.
- Script passes shell syntax checks and help output still renders.
