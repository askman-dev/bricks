# OpenClaw Gap Audit and Token Chain Validation (Consolidated)

## Background
The previous iteration produced multiple short plan files and partial implementation updates. This consolidated document merges the current review context and implementation goals into a single artifact.

## Goals
1. Compare target requirements from post-main docs with current implementation status.
2. Close critical integration gaps for remote OpenClaw/小龙虾 token flow.
3. Ensure the user journey is end-to-end: generate token in Settings -> configure external server -> external server connects back and sends messages.

## Implementation Plan (phased)
### Phase 1: Gap audit
- Verify target vs implementation for pull-only APIs and auth model.
- Confirm whether Settings currently exposes OpenClaw token issuance.

### Phase 2: Gap closure
- Add backend token-issuance endpoint for authenticated users.
- Support JWT platform tokens in platform auth middleware.
- Wire Settings UI to request, show, and copy the OpenClaw token bundle.

### Phase 3: Validation
- Add/extend automated tests for token retrieval and copy behavior.
- Verify backend type-check and platform route tests.

## Acceptance Criteria
- Settings page can fetch and copy a dedicated OpenClaw token.
- External service can use that token with `X-Bricks-Plugin-Id` against `/api/v1/platform/*`.
- Platform middleware accepts scoped JWT tokens and enforces plugin identity constraints.
- Consolidated planning is captured in one markdown file for this iteration.
