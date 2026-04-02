# Background
A pull request workflow run reported `.github/workflows/ai_provider_smoke_test.yml` as invalid because the integration test step used `secrets.*` directly in an `if` expression. GitHub Actions does not allow directly referencing `secrets` in `if` conditionals.

# Goals
- Fix workflow syntax so the file validates.
- Preserve current behavior: only run real-API integration tests when at least one test API key is present.
- Keep the smoke test job stable for pull requests and manual dispatch.

# Implementation Plan (phased)
## Phase 1: Update workflow conditions
- Add job-level environment variables that map to existing secret values.
- Replace step-level `if` expression to use `env.*` variables instead of `secrets.*`.

## Phase 2: Validate changes
- Run a local YAML sanity check (structure/format).
- Review the updated workflow lines to ensure no behavior regressions in test execution.

# Acceptance Criteria
- `.github/workflows/ai_provider_smoke_test.yml` no longer references `secrets.*` directly in an `if` condition.
- Integration step condition evaluates based on environment variables derived from those secrets.
- Workflow remains readable and consistent with existing test setup.
