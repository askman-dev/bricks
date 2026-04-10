# Background
The user reported that the current refactor branch appears to have lost many capabilities. The task requires broad traversal across code, docs, and backend-driven behavior checks, then repairing incorrect implementations.

# Goals
1. Enumerate currently implemented capabilities across backend, web frontend, and developer tooling.
2. Validate behavior using runnable checks (tests/build/bootstrap script).
3. Repair concrete regressions found during traversal.
4. Re-verify repaired behavior and summarize remaining risk.

# Implementation Plan (phased)
## Phase 1: Capability traversal and baseline verification
- Read top-level docs (`README.md`, backend API reference) to establish expected capabilities.
- Run workspace bootstrap entrypoint (`./tools/init_dev_env.sh`) as the canonical environment check.
- Run backend/frontend test and build pipelines to verify core runtime flows.

## Phase 2: Regression diagnosis and implementation fixes
- Inspect failing paths and supporting shared scripts.
- Patch broken shared shell helpers used by bootstrap scripts.
- Align tooling documentation with current Node/React architecture to prevent operator confusion.

## Phase 3: Post-fix validation
- Re-run bootstrap script.
- Re-run backend/frontend tests and builds for regression safety.
- Record what was fixed and any residual gaps.

# Acceptance Criteria
1. `./tools/init_dev_env.sh` completes successfully from repo root.
2. Backend tests pass via `npm --prefix apps/node_backend test`.
3. Frontend tests pass via `npm --prefix apps/web_chat_app run test`.
4. Backend and frontend production builds pass.
5. Tooling docs reflect current implementation (Node backend + React frontend) rather than removed Flutter bootstrap behavior.
