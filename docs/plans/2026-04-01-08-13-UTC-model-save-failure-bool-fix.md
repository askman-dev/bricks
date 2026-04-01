# Background
On the Model Settings screen, changing the default model name and pressing Save currently shows "Failed to save model settings". The mobile client sends `is_default` as numeric `1/0`, while the Node backend route and DB update path expect a boolean value.

# Goals
1. Make model settings save succeed when editing model names.
2. Keep compatibility when reading `is_default` from either boolean or numeric payloads.
3. Add focused test coverage for request payload shape and response parsing.

> **Note:** Phase 1 below was superseded by follow-up feedback. The chosen wire format is numeric `1/0` (not boolean). The backend now normalizes both formats; see `docs/plans/2026-04-01-08-56-UTC-model-is-default-number-format.md` and `docs/plans/2026-04-01-09-22-UTC-backend-is-default-normalization.md`.

# Implementation Plan (phased)
## Phase 1: Save payload contract alignment (superseded)
- ~~Update Flutter `LlmConfigService.save` to send `is_default` as a boolean.~~
- **Actual decision:** Keep mobile sending numeric `1/0`; add route-level normalization on the backend to accept boolean, numeric, and string representations.

## Phase 2: Defensive response parsing
- Update `is_default` parsing helper to accept booleans and numeric/string equivalents without throwing.

## Phase 3: Validation
- Add unit tests around `LlmConfigService` save payload and parse behavior.
- Run repository bootstrap and targeted Flutter tests.

# Acceptance Criteria
- Saving model settings after changing the model name no longer shows the failure snackbar for valid requests.
- Save request payload sends `is_default` as `1` or `0` (numeric).
- Backend accepts `is_default` as boolean, `0/1`, or `"true"`/`"false"` for backward compatibility.
- Parsing handles backend responses with either `true/false` or `1/0` safely.
