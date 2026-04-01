# Background
PR #77 review comments flagged edge cases in slot-id churn and `is_default` parsing strictness.

# Goals
1. Avoid slot id churn when default model input is empty.
2. Parse `is_default` strictly as 0/1 for number-style contract.
3. Keep UI hint and save behavior aligned for empty model names.

# Implementation Plan (phased)
## Phase 1: Save-path slot handling
- Preserve existing slot id if default model is blank during save.

## Phase 2: Strict is_default parsing
- Accept numeric 0/1 only; treat unexpected numeric values as false and log.

## Phase 3: UI slot synchronization
- Update model `onChanged` logic to keep existing slot when model is blank.

## Phase 4: Validation
- Run init, format, and targeted app test.

# Acceptance Criteria
- Clearing model input does not generate timestamp-based slot ids in local state.
- Save uses existing slot id when model input is blank.
- `is_default` parser only treats 1 as true and 0 as false for numeric values.
