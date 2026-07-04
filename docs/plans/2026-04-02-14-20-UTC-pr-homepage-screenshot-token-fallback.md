# Background
The `PR Frontend E2E` workflow can fail in the `Publish screenshot to PR comment` step when no dedicated PAT-like secret is configured. The publish script currently throws immediately if neither `GITHUB_TOKEN` nor `GH_TOKEN` is present, which causes the job to fail even though screenshot generation itself succeeded.

# Goals
1. Prevent false-negative workflow failures caused by missing optional custom token configuration.
2. Keep PR screenshot publishing functional by using built-in GitHub token fallbacks.
3. Provide clearer script behavior when no token is available.

# Implementation Plan (phased)
## Phase 1: Workflow token fallback
- Update `.github/workflows/pr_frontend_e2e.yml` so the publish step injects `GITHUB_TOKEN` from a fallback chain (`GH_TOKEN`, then default `github.token`).

## Phase 2: Script resilience
- Update `.github/scripts/publish_pr_homepage_screenshot.js` to avoid hard failure when no token is available.
- Add a warning and exit successfully when token is missing so E2E validation/artifact upload still pass.

## Phase 3: Validation
- Run targeted checks (`node --check`) for the updated script and verify git diff for workflow/script consistency.

# Acceptance Criteria
1. A PR run without custom PAT configuration no longer fails solely due to missing token in screenshot publish step.
2. Screenshot publish step still attempts to post/update PR comment when any valid token is available.
3. If no token is present, logs show a clear warning and the step exits without failing the full workflow.
4. Updated script passes `node --check .github/scripts/publish_pr_homepage_screenshot.js`.
