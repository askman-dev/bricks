# Background
The current PR frontend E2E workflow still uses a removed Flutter web build and only validates homepage rendering via a static screenshot script. It does not exercise the current React + Node stack, does not perform a real login sequence, and does not prove navigation into the chat conversation page.

# Goals
1. Make the automation run against the active stack (Node backend + React frontend).
2. Execute a real browser login interaction (click login entry and complete backend auth redirect flow).
3. Assert E2E reaches the chat page and capture evidence screenshot after login.
4. Keep PR comment publishing aligned with the new chat-page-oriented flow.

# Implementation Plan (phased)
## Phase 1: Backend test-auth support for CI E2E
- Add a guarded mock-GitHub auth path in `apps/node_backend/src/routes/auth.ts`.
- Reuse existing login token + redirect logic so the flow mirrors production behavior.
- Gate mock mode behind explicit env flags and non-production runtime.

## Phase 2: Workflow and E2E runner migration
- Replace Flutter build/serve steps in `.github/workflows/pr_frontend_e2e.yml` with:
  - Node backend install + startup
  - React frontend install + Vite dev startup with API proxy
  - Playwright run against live app
- Update `.github/scripts/e2e_homepage_screenshot.js` to perform:
  - Open login page
  - Click “Login with GitHub”
  - Wait for redirect to `/chat`
  - Validate chat composer/message region and capture screenshot.

## Phase 3: PR comment and code map maintenance
- Update `.github/scripts/publish_pr_homepage_screenshot.js` text and filename references for chat-page verification.
- Synchronize `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` with the changed E2E index/coverage.

# Acceptance Criteria
1. PR frontend E2E workflow no longer depends on Flutter build artifacts and runs on web + backend Node services.
2. Playwright script performs interactive login click and confirms `/chat` page content is rendered.
3. Screenshot artifact reflects post-login chat page state.
4. Auth route tests and affected frontend/backend tests pass.
5. Code map files are reviewed/updated to reflect E2E test entry and risk coverage changes.
