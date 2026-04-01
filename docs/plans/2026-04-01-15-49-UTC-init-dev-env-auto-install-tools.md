# Background
Current bootstrap behavior checks for `curl` and `jq` but exits on missing commands. The expected behavior is to proactively fix missing environment dependencies during initialization instead of failing immediately.

# Goals
- Make `tools/init_dev_env.sh` attempt to install missing `curl`/`jq` automatically.
- Keep checks explicit and retain clear error messaging when auto-install cannot be completed.
- Preserve compatibility across common package managers used in local and container environments.

# Implementation Plan (phased)
## Phase 1: Add installer helpers
- Add package-manager detection and install helpers (`apt-get`, `dnf`, `yum`, `apk`, `pacman`, `brew`).
- Add a wrapper that installs missing command dependencies before validating them.

## Phase 2: Integrate into init flow
- Replace hard-fail `ensure_cmd curl/jq` with auto-install flow in `main`.
- Keep final `ensure_cmd` validation to guarantee command availability after install attempts.

## Phase 3: Validate
- Run shell syntax checks.
- Run `--help` path.
- Simulate package-manager detection branch with available tooling.

# Acceptance Criteria
- Missing `jq` or `curl` triggers an automatic install attempt during init.
- If install succeeds, init continues normally.
- If install cannot be performed, error output explains why and what to run manually.
