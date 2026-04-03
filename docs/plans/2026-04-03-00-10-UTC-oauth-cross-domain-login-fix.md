# Background
Preview environments use dynamic Vercel subdomains that differ from the custom production domain.
The OAuth flow intentionally redirects across domains, but users can return unauthenticated after GitHub login.

Current callback behavior writes JWT to callback-origin localStorage and then redirects to `return_to`.
For cross-origin redirects, the destination origin cannot read callback-origin localStorage.

# Goals
1. Preserve successful login across cross-origin callback → return_to redirects.
2. Keep same-origin behavior unchanged.
3. Avoid leaking token in query parameters sent to servers.
4. Add automated tests for redirect-target generation behavior.

# Implementation Plan (phased)
## Phase 1: Backend cross-origin redirect token handoff
- Add a helper that builds post-login redirect URLs.
- If callback origin differs from return_to origin, attach JWT in URL fragment (`#auth_token=...`).
- Keep same-origin redirects unchanged.

## Phase 2: Frontend fragment token consumption
- Add web-only fragment parser to read `auth_token` from location hash.
- Persist token through AuthService startup path.
- Remove consumed token from URL via history.replaceState.

## Phase 3: Validation
- Add backend unit tests covering same-origin, cross-origin, and existing-fragment cases.
- Run Node backend test suite.

# Acceptance Criteria
- Cross-origin OAuth redirect includes `#auth_token` fragment.
- Web startup consumes fragment token and login state becomes authenticated.
- Same-origin flow does not append token to URL.
- Backend tests pass with new redirect-target cases.
