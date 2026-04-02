# Background
PR #100 (`Allow callback-origin GitHub OAuth return_to and extract validator`) was manually merged on April 2, 2026. Before manual merge, several workflows executed, while some expected pull-request workflows did not run after Copilot-generated follow-up commits.

# Goals
- Identify which workflows ran and which did not run before merge.
- Confirm whether `PR Review Thread Auto Resolver` was among the workflows that did not run.
- Determine the likely reason missing workflows did not trigger.

# Implementation Plan (phased)
## Phase 1: Collect run data by PR commit SHA
- Query PR metadata and commit SHAs for PR #100.
- Query Actions workflow runs for each head SHA used in the PR.
- Compare run events and workflow names per SHA.

## Phase 2: Map workflows to trigger conditions
- Inspect `.github/workflows/*.yml` trigger definitions.
- Classify workflows expected on `pull_request`, `pull_request_target`, `pull_request_review`, and manual events.

## Phase 3: Explain non-triggered workflows
- Verify whether `synchronize`-driven workflows appeared for follow-up commits.
- Use evidence (absence of `pull_request` / `pull_request_target` runs on later SHAs while `push` run exists) to infer trigger gap cause.
- Document likely mechanism and suggested mitigations.

# Acceptance Criteria
- A list exists of workflows that ran before merge and workflows that did not run for the two follow-up SHAs.
- The list explicitly states, with supporting workflow/run evidence, whether `PR Review Thread Auto Resolver` ran for PR #100 follow-up commits (and, if it did run, under which SHA and event).
- The explanation ties missing runs to concrete trigger/event evidence (by SHA and event type).
- Mitigation options are provided (e.g., broaden triggers, add manual fallback, or use `workflow_run` chaining).
