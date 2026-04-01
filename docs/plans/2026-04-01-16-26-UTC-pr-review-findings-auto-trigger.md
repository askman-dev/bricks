# Background
PR authors currently need to manually add an `@copilot` follow-up comment after a review is submitted with actionable findings. This creates repetitive work and inconsistent timing for starting Copilot-based review-fix workflows.

# Goals
- Automatically detect `pull_request_review` submissions that should trigger Copilot follow-up.
- Post a single trigger comment per submitted review when that review has comments.
- Prevent duplicate comments during reruns and concurrent executions.
- Emit clear run-time telemetry and actionable error messages.

# Implementation Plan (phased)
1. Add a dedicated GitHub Actions workflow triggered by `pull_request_review` `submitted` events.
2. Enforce PR-scoped workflow concurrency with `cancel-in-progress: true`.
3. Implement a decision step that:
   - validates review state (`commented` or `changes_requested`),
   - counts comments for the current review,
   - checks existing PR comments for a per-review idempotency marker.
4. Post the default Copilot trigger comment only when all conditions pass, appending an HTML marker keyed by `review_id`.
5. Print structured observability output (PR number, review id/state, comments count, triggered flag, skip reason), and provide permission remediation hints on API failures.

# Acceptance Criteria
- A single review submission with multiple review comments creates exactly one `@copilot` trigger comment.
- Re-running the same workflow for the same `review_id` does not add a second trigger comment.
- Reviews with zero comments do not create trigger comments.
- If token permissions are insufficient, logs include both the API error and a remediation hint indicating required scopes (`pull_requests: read`, `issues: write` or `pull_requests: write`).
