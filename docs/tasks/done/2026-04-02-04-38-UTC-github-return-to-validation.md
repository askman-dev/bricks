# Background
Users hitting `/api/auth/github` with `return_to=https://bricks.askman.dev/` can receive `{"error":"Invalid return_to URL"}` when `OAUTH_ALLOWED_RETURN_ORIGINS` does not include the production app origin.

# Goals
- Accept secure first-party `return_to` values that match the configured OAuth callback origin.
- Preserve existing security checks for localhost/protocol restrictions.
- Add regression tests for return URL validation.

# Implementation Plan (phased)
1. Update `isAllowedReturnTo` in `apps/node_backend/src/routes/auth_return_to.ts` to allow same-origin redirects derived from `GITHUB_CALLBACK_URL`.
2. Keep existing preview-domain and explicit allowlist checks intact.
3. Add unit tests in `apps/node_backend/src/routes/auth_return_to.test.ts` for callback-origin allow, HTTP rejection on non-localhost, and explicit allowlist behavior.
4. Run backend test/lint/type-check commands.

# Acceptance Criteria
- A `return_to` URL that is HTTPS and matches the origin of `GITHUB_CALLBACK_URL` is accepted.
- Non-HTTPS non-localhost return URLs remain rejected.
- Existing allowlist behavior via `OAUTH_ALLOWED_RETURN_ORIGINS` still works.
- `npm test`, `npm run lint`, and `npm run type-check` pass in `apps/node_backend`.
