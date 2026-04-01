# Background
The model settings page currently shows a generic "Failed to save model settings" snackbar when saving some valid backend responses. The sample API response includes `is_default: 1` (numeric), while the Flutter parser expects a boolean and can throw at runtime during response hydration. Additionally, users expect the saved config slot name (`config.slot_id`) to track the chosen model name.

# Goals
1. Make Save succeed for backend responses that represent booleans as numeric values.
2. Ensure persisted `config.slot_id` stays aligned with the selected default model name after save.
3. Keep UI labels for config chips consistent with current model naming.

# Implementation Plan (phased)
## Phase 1: Robust API response parsing
- Update model config deserialization in `LlmConfigService` to accept boolean-like values (`true/false`, `1/0`, and string variants) for `is_default`.

## Phase 2: Slot/model alignment
- Add a slot-id normalization helper derived from the selected model name.
- Use normalized slot id in save payload and in local state updates after save.
- Keep fallback behavior stable for malformed/empty model names.

## Phase 3: Validation
- Run formatting and targeted Flutter checks after bootstrapping via `./tools/init_dev_env.sh`.

# Acceptance Criteria
- Saving settings with a backend response like `"is_default": 1` no longer triggers the failure snackbar.
- After save, the stored config `slot_id` matches a normalized form of the selected default model (e.g., `gemini-flash-latest` remains the same).
- Config selector labels continue to reflect model names and remain stable after save/reload.
