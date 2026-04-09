# Smoke Tests Workflow Refactor Plan

## Background
The existing smoke test GitHub Actions workflow (`.github/workflows/ai_provider_smoke_test.yml`) is still tied to the removed Flutter/Dart smoke test package (`packages/bricks_ai_smoke_test`) and Melos bootstrap flow. After the frontend stack migration to React + Node.js, this workflow no longer reflects the active code paths and creates maintenance risk.

## Goals
1. Refactor the smoke test workflow to validate the current runnable stack (Node backend + React frontend).
2. Keep smoke checks fast and deterministic for pull requests.
3. Preserve manual dispatch support for on-demand verification.

## Implementation Plan (phased)
1. **Workflow scope and trigger update**
   - Replace obsolete Flutter/Dart package path filters with active paths under `apps/node_backend`, `apps/web_chat_app`, and the workflow file itself.
2. **Job topology refactor**
   - Replace legacy Melos-based single job with two explicit jobs:
     - backend smoke checks (Node install + type-check + tests)
     - frontend smoke checks (Node install + tests + build)
   - Add least-privilege workflow permissions and concurrency cancellation.
3. **Validation**
   - Validate workflow YAML syntax locally and ensure only intended workflow/plan files changed.

## Acceptance Criteria
1. `.github/workflows/ai_provider_smoke_test.yml` no longer depends on Flutter, Dart, Melos, or removed package directories.
2. Pull requests touching backend/frontend source paths trigger smoke checks for the corresponding Node/React stack.
3. The workflow remains manually runnable via `workflow_dispatch`.
