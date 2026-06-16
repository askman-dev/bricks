# Background
Follow-up feedback requires `is_default` to use number-style values (`0/1`) instead of booleans (`true/false`) in model settings payloads.

# Goals
1. Restore `is_default` request payload format to `0/1`.
2. Keep save behavior stable for model name edits.
3. Validate the mobile app tests still pass.

# Implementation Plan (phased)
## Phase 1: Payload format correction
- Update `LlmConfigService.save` to encode `is_default` as numeric `1` or `0`.

## Phase 2: Parser alignment
- Keep response parsing aligned with number-style contract and avoid boolean-first behavior.

## Phase 3: Validation
- Run bootstrap and mobile Flutter test suite.

# Acceptance Criteria
- Save payload sends `is_default` as `1` or `0`.
- Editing model name and saving no longer fails due to payload type mismatch.
- `flutter test` for `apps/mobile_chat_app` passes.
