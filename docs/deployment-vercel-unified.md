# Validating and Implementing Unified Same-Domain Vercel Deployment

> **This document is the corrected and actionable version of [issue #39](https://github.com/askman-dev/bricks/issues/39).**
> The original issue was written in Chinese and proposed a direct configuration change as a ready-to-execute recipe. This document reframes it as a phased engineering task that requires verification before any production changes are made.

---

## Objective

Validate whether `askman-dev/bricks` can be deployed on Vercel so that:

- `https://bricks.askman.dev/` → Flutter Web frontend (static assets)
- `https://bricks.askman.dev/api/*` → Node.js backend API

This same-domain setup would simplify CORS configuration and consolidate GitHub OAuth callback URLs. The goal is correct; the original proposal's implementation details are not yet verified to be safe or accurate.

---

## Current Repository State

Before making any changes it is important to understand where things stand today.

| Area | Current state |
|---|---|
| Root `vercel.json` | **Does not exist**. The repository has no root-level Vercel configuration. |
| Frontend deployment | **GitHub Pages** via `.github/workflows/deploy_web.yaml`. Builds Flutter Web from `apps/mobile_chat_app` and publishes `apps/mobile_chat_app/build/web` to the `gh-pages` branch. |
| Flutter Web build output | `apps/mobile_chat_app/build/web` — this is the artifact that must be served, not the source directory `apps/mobile_chat_app/web/`. |
| Backend entry point | `apps/node_backend/src/index.ts` — a traditional Express application that calls `app.listen(PORT)` after testing the database connection and running auto-migrations. |
| Backend Vercel config | `apps/node_backend/vercel.json` already exists, indicating the backend is currently organised as an independently deployable Vercel target. |
| Root `package.json` | **Does not exist**. This is a Dart/Flutter + Node monorepo managed with Melos, not a JavaScript workspace. |

---

## Why the Original Proposal Is Unsafe

The original issue body proposed a root-level `vercel.json` containing:

```json
{
  "version": 2,
  "routes": [
    { "src": "/api/(.*)", "dest": "/apps/node_backend/src/index.ts" },
    { "src": "/(.*)",     "dest": "/apps/mobile_chat_app/web/index.html" }
  ]
}
```

This configuration has multiple problems:

1. **The backend is not a Vercel serverless function.**
   `apps/node_backend/src/index.ts` calls `app.listen(PORT)`, connects to a database, and runs migrations before the server is ready. Vercel's routing model expects a serverless handler export, not a long-running process. Pointing a route at this file will not work without a backend refactor.

2. **The frontend source directory is not the build output.**
   `apps/mobile_chat_app/web/index.html` is a source file used during development and Flutter compilation. The deployable artifact is `apps/mobile_chat_app/build/web`, which is only present after running `flutter build web`. Serving the source file will not produce a working Flutter Web application.

3. **Deleting `apps/node_backend/vercel.json` removes the only validated fallback.**
   The original issue includes a step to delete this file. Until a unified deployment is fully verified in production, removing this file eliminates the ability to roll back to an independent backend deployment.

4. **Replacing GitHub Pages without a validated alternative breaks the frontend.**
   The current GitHub Pages workflow is the only production-tested frontend publishing path. Switching to Vercel static hosting requires a verified build pipeline before the GitHub Pages workflow can be retired.

5. **Environment variable boundary is unclear.**
   Saying "frontend and backend share the same environment variables" is misleading. Sensitive backend secrets must never be injected into the client-side bundle. The boundary must be explicit before a unified Vercel project is configured.

---

## Phased Task Breakdown

### Phase 1 — Pre-flight verification (no production changes)

- [ ] Confirm whether `apps/node_backend/src/index.ts` can be adapted to export a Vercel-compatible serverless handler while retaining the existing database initialisation and migration logic.
- [ ] Confirm that `flutter build web` succeeds in a Vercel build environment (Flutter is not installed by default; a custom install step is required).
- [ ] Confirm that the build output path (`apps/mobile_chat_app/build/web`) is compatible with Vercel's static-file serving when used from a monorepo root deployment.
- [ ] Confirm that a root-level `vercel.json` correctly overrides the existing `apps/node_backend/vercel.json` in Vercel's project resolution model, or decide whether the two projects should remain separate Vercel deployments behind a shared domain.
- [ ] Confirm that the `/api/*` route will not be swallowed by Flutter Web's SPA fallback handler.
- [ ] Confirm that the database connection and migration step can run safely inside a serverless invocation (cold-start latency, connection pooling).

### Phase 2 — Deployment design

- [ ] Decide whether to pursue a **single Vercel project** (unified root deployment) or **two separate Vercel projects** (backend project + frontend project) both fronted by the same domain through Vercel's domain routing or a CDN/edge proxy.
- [ ] Define the GitHub OAuth strategy for each environment:
  - Production: `https://bricks.askman.dev/api/auth/github/callback`
  - Vercel Preview: disabled or a separate OAuth App with a preview callback
  - Local development: separate OAuth App
- [ ] Define the environment variable boundary:
  - **Server-side only (never in client bundle):** `DATABASE_URL`, `JWT_SECRET`, `ENCRYPTION_KEY`, `GITHUB_CLIENT_SECRET`
  - **Safe to expose to the frontend:** `GITHUB_CLIENT_ID`, any explicitly approved public configuration
- [ ] Draft the root-level `vercel.json` (or per-project configs) based on findings from Phase 1.
- [ ] Write a rollback procedure covering both the frontend (restore GitHub Pages deployment) and the backend (restore independent `apps/node_backend` Vercel project).

### Phase 3 — Staged rollout

- [ ] Deploy to a Vercel Preview environment and validate all acceptance criteria below.
- [ ] Update the GitHub OAuth App callback URL to the production domain only after preview validation passes.
- [ ] Configure DNS: add `CNAME bricks → cname.vercel-dns.com` in the `askman.dev` DNS zone.
- [ ] Set all production environment variables in the Vercel Dashboard before the first production deployment.
- [ ] Keep the GitHub Pages deployment active until the Vercel production deployment is confirmed healthy.
- [ ] Only retire `apps/node_backend/vercel.json` and the GitHub Pages workflow **after** the unified deployment has been stable in production for at least one deployment cycle.

---

## Acceptance Criteria

### Functional

- [ ] `https://bricks.askman.dev/` loads the Flutter Web application homepage.
- [ ] `https://bricks.askman.dev/api/health` returns HTTP 200 with a JSON body.
- [ ] GitHub OAuth login completes successfully; `https://bricks.askman.dev/api/auth/github/callback` is reachable and processes the callback correctly.
- [ ] Frontend `fetch('/api/…')` calls do not require CORS workarounds.

### Deployment

- [ ] Vercel production deployment succeeds without errors in the build log.
- [ ] Flutter Web build output (`apps/mobile_chat_app/build/web`) is served correctly from the root path.
- [ ] The Node.js API responds at `/api/*` without relying on a long-running process; it must not call `app.listen()` in the Vercel handler path.
- [ ] Vercel Preview deployments do not use the production GitHub OAuth configuration.

### Safety

- [ ] No sensitive environment variable (`DATABASE_URL`, `JWT_SECRET`, `ENCRYPTION_KEY`, `GITHUB_CLIENT_SECRET`) appears in the Flutter Web client bundle.
- [ ] A rollback to the current GitHub Pages + independent Vercel backend deployment is documented and can be executed without data loss.
- [ ] This work does not regress the login functionality introduced in issue #35.

---

## Implementation Order of Operations

1. **Backend serverless adapter** — assess whether `src/index.ts` needs a thin wrapper that skips `app.listen()` when running inside Vercel's serverless runtime (e.g. by checking for the absence of a direct invocation context).
2. **Flutter Web build in CI** — validate `flutter build web` in a non-local environment (GitHub Actions or Vercel build hook) before assuming it works on Vercel.
3. **Root `vercel.json` draft** — only after steps 1 and 2 are confirmed, draft the unified configuration. Use Vercel's `rewrites` (not legacy `routes`) unless the legacy format is explicitly required.
4. **Preview deployment validation** — deploy to preview, run the acceptance criteria manually, capture logs.
5. **Production cutover** — update DNS, OAuth callback, and environment variables. Keep GitHub Pages live in parallel until health checks pass.
6. **Decommission old configs** — remove `apps/node_backend/vercel.json` and retire the GitHub Pages workflow only after the unified deployment is confirmed stable.

---

## Environment Variable Boundary Guidance

```
┌──────────────────────────────────────────────────────────────────┐
│  Vercel Project Environment Variables                            │
│                                                                  │
│  Server-side only (Vercel: no "NEXT_PUBLIC_" or equivalent)      │
│  ──────────────────────────────────────────────────────────      │
│  DATABASE_URL          – PostgreSQL connection string            │
│  JWT_SECRET            – Token signing secret                    │
│  ENCRYPTION_KEY        – AES-256-GCM key for API config          │
│  GITHUB_CLIENT_SECRET  – OAuth App secret                        │
│                                                                  │
│  Exposed to frontend build (set explicitly, verify each one)     │
│  ──────────────────────────────────────────────────────────      │
│  GITHUB_CLIENT_ID      – OAuth App client ID (public)            │
│  (any other value must be approved before being added here)      │
└──────────────────────────────────────────────────────────────────┘
```

**Critical rule:** if a variable is not in the "Exposed to frontend build" list above, it must not be injected into the Flutter Web build process.

---

## Rollback Requirement

Before any production change is made, the following rollback steps must be documented and validated:

1. **Frontend rollback:** re-enable or confirm the GitHub Pages deployment by pushing a commit that triggers `.github/workflows/deploy_web.yaml`. The `gh-pages` branch content should be retained (do not delete it).
2. **Backend rollback:** if `apps/node_backend/vercel.json` has not yet been deleted, re-deploy the independent backend Vercel project from the `apps/node_backend` directory with existing environment variables intact.
3. **DNS rollback:** revert the `CNAME bricks` record to its previous target.
4. **OAuth rollback:** restore the previous GitHub OAuth App callback URL.

---

## Related

- Issue #35 — User login enhancement (must not be regressed by this work)
- `.github/workflows/deploy_web.yaml` — current frontend deployment workflow
- `apps/node_backend/vercel.json` — current independent backend Vercel configuration
- `apps/node_backend/src/index.ts` — Express entry point with `app.listen()` startup
