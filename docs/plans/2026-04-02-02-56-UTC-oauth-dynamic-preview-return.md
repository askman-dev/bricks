# Background
GitHub OAuth callback URL must stay fixed, but preview deployments run on dynamic Vercel hostnames. Current login flow always redirects to `/` after callback, so users starting on preview URLs cannot reliably return to their originating deployment.

# Goals
1. Keep existing callback path unchanged.
2. Allow login initiated from preview domains matching `bricks-<alnum>-askman-dev.vercel.app`.
3. Validate the requested start/return URL before redirecting to GitHub.
4. Return users to the validated originating URL after callback.

# Implementation Plan (phased)
## Phase 1: OAuth return URL validation and state transport
- Add a backend helper that validates `return_to` values using:
  - `https` protocol
  - host pattern `^bricks-[A-Za-z0-9]+-askman-dev\.vercel\.app$`
  - optional allowlist from env for stable first-party domains
  - localhost allowances for dev
- On `/auth/github`, accept `return_to` query and validate it.
- Put `{ nonce, returnTo }` inside OAuth `state` payload while continuing CSRF cookie nonce checking.

## Phase 2: Callback redirect behavior
- Decode `state` in callback.
- Verify nonce against cookie and extract validated `returnTo`.
- Keep callback path unchanged and only alter query/state behavior.
- Update redirect response HTML to navigate to `returnTo` instead of always `/`.

## Phase 3: Docs and validation
- Update backend API docs and README to document `return_to` behavior and domain constraints.
- Run backend type-check and tests.

# Acceptance Criteria
1. `GET /api/auth/github?return_to=https://bricks-abc123-askman-dev.vercel.app/` redirects to GitHub with encoded state that includes that return URL.
2. `GET /api/auth/github?return_to=https://evil.example.com/` is rejected with HTTP 400.
3. Callback continues to use the existing path and succeeds when `state.nonce` matches cookie nonce.
4. Successful callback redirects browser to the validated `returnTo` URL.
5. Backend checks (`npm run type-check`, `npm test`) pass.
