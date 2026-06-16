# Background
Review feedback requested avoiding broad compatibility coercion for `is_default` and instead using a clear API contract. Current backend responses are number-style (`1`/`0`), so client-side conversion should align with that representation.

# Goals
1. Use number-style `is_default` in request payloads.
2. Parse `is_default` from number-style response values with strict semantics.
3. Keep internal UI/domain behavior unchanged (still boolean in app state).

# Implementation Plan (phased)
## Phase 1: Contract alignment in serialization
- Update save payload mapping to send `is_default` as `1` or `0`.

## Phase 2: Strict deserialization
- Replace permissive boolean parser with a number-style parser dedicated to API contract values.
- Keep a narrow fallback for bool only if required by runtime typing differences.

## Phase 3: Validation
- Run formatter and app test command after environment bootstrap.

# Acceptance Criteria
- Save requests send `is_default` as number-style values (`1` or `0`).
- Response parsing no longer relies on generic string coercion for `is_default`.
- Existing app test command still passes.
