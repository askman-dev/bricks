# Background
The client is using number-style `is_default` values (`0/1`) per product expectation. The backend route layer currently forwards `is_default` directly, and the service/database layer expects a boolean, which can still cause save failures depending on runtime coercion.

# API Conventions
**Boolean fields at the API level use numeric `0/1`, not JSON `true/false`.**
- Callers MUST send `is_default` (and any future boolean fields) as integer `1` or `0`.
- The backend normalizes JSON booleans and string forms for backward compatibility only; new clients should always use `0/1`.

# Goals
1. Ensure backend accepts `0/1` for `is_default` without save failures.
2. Preserve compatibility with boolean payloads.
3. Return clear 400 errors for invalid `is_default` values.

# Implementation Plan (phased)
## Phase 1: Route-level normalization
- Add a route helper to normalize `is_default` values to boolean.
- Apply normalization in both POST and PUT config handlers.

## Phase 2: Validation behavior
- Reject unsupported values with HTTP 400 and an explicit error message.

## Phase 3: Validation
- Run backend type-check and backend tests.

# Acceptance Criteria
- Requests with `is_default: 1` or `is_default: 0` save successfully.
- Requests with `is_default: true/false` remain supported.
- Invalid values like `is_default: 2` return HTTP 400.
