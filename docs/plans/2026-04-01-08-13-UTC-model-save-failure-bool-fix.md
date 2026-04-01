# Background
On the Model Settings screen, changing the default model name and pressing Save currently shows "Failed to save model settings". The mobile client sends `is_default` as numeric `1/0`, while the Node backend route and DB update path expect a boolean value.

# Goals
1. Make model settings save succeed when editing model names.
2. Keep compatibility when reading `is_default` from either boolean or numeric payloads.
3. Add focused test coverage for request payload shape and response parsing.

# Implementation Plan (phased)
## Phase 1: Save payload contract alignment
- Update Flutter `LlmConfigService.save` to send `is_default` as a boolean.

## Phase 2: Defensive response parsing
- Update `is_default` parsing helper to accept booleans and numeric/string equivalents without throwing.

## Phase 3: Validation
- Add unit tests around `LlmConfigService` save payload and parse behavior.
- Run repository bootstrap and targeted Flutter tests.

# Acceptance Criteria
- Saving model settings after changing the model name no longer shows the failure snackbar for valid requests.
- Save request payload includes boolean `is_default`.
- Parsing handles backend responses with either `true/false` or `1/0` safely.
