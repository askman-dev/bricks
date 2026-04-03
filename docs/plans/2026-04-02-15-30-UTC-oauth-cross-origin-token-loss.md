# Background
The user suspects this sequence in GitHub OAuth web login:
1. Browser starts on `https://bricks.askman.dev`.
2. Redirects to GitHub and back to `https://bricks.askman.dev` callback.
3. Then redirects to `https://bricks-aoqjuy2sr-askman-dev.vercel.app` but appears to lose parameters and lands unauthenticated.

The task is to validate this hypothesis and identify where auth state is lost.

# Goals
1. Verify whether `return_to` is preserved in OAuth state.
2. Verify how callback passes auth token back to Flutter web app.
3. Determine whether cross-origin redirects (`bricks.askman.dev` -> `*.vercel.app`) can lose token persistence.
4. Propose a concrete next-step fix strategy.

# Implementation Plan (phased)
## Phase 1: Confirm return_to propagation
- Inspect backend `/api/auth/github` behavior.
- Trigger a real redirect response and decode `state` payload to confirm `returnTo` value.

## Phase 2: Confirm token handoff mechanism
- Inspect callback response builder in backend.
- Check whether token is returned in URL params vs browser storage.

## Phase 3: Cross-origin risk assessment
- Compare callback origin and `returnTo` origin behavior.
- Validate whether `localStorage` write happens on callback origin only.
- Determine impact when final redirect target is a different origin.

## Phase 4: Remediation path
- Prefer same-origin callback and return target for web login.
- If cross-origin is required, implement explicit token transfer (e.g., fragment/postMessage + one-time exchange), then clear token artifact.
- Add integration checks for preview-domain and custom-domain flows.

# Acceptance Criteria
- Evidence shows whether state contains the expected `returnTo` URL.
- Evidence shows whether token is delivered via localStorage or URL.
- A clear conclusion states whether cross-origin redirect can explain "returned but still not logged in".
- Next implementation step is actionable and testable.

# Findings (current investigation)
- Backend includes `returnTo` in OAuth `state` and stores nonce server-side.
- Live redirect test confirmed `state.returnTo = https://bricks-aoqjuy2sr-askman-dev.vercel.app/`.
- Callback success page writes token to `localStorage` key `flutter.auth_token` and then `window.location.replace(redirectTo)`.
- `localStorage` is origin-scoped; therefore token written on `https://bricks.askman.dev` is not available on `https://bricks-aoqjuy2sr-askman-dev.vercel.app`.
- This explains why "no URL params + returned unauthenticated" can happen even when OAuth callback is successful.
