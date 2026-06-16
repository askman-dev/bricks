# Background
The Model Settings screen intentionally leaves the API key input empty for persisted configurations so users can save changes without overwriting secrets. This behavior is correct, but users can misread the empty field as "not configured".

Earlier iterations explored a dedicated `hasStoredApiKey` flag and then a simpler approach using masked `api_key` returned by the backend. The final direction is to keep the simpler model and provide a clear visual cue only.

# Goals
- Keep existing save semantics unchanged (blank API key input means do not update key).
- Show an in-field parenthesized gray hint when a server-side key exists but is hidden for safety.
- Keep implementation minimal and maintainable.

# Implementation Plan (phased)
1. Use parsed `config.api_key` (masked from backend) as a display-state indicator.
2. Keep API key text controller empty in form hydration so masked value is never prefilled/submitted.
3. Render `hintText` in API key input when the active config has non-empty `apiKey`.
4. Keep helper text (`Leave blank to keep your existing key`) unchanged.
5. Cover behavior with widget test for persisted config with masked key.

# Acceptance Criteria
- Persisted configs with a stored key show a one-line parenthesized hint in the API key input.
- No secret value is displayed in the input field.
- Leaving API key blank while editing still preserves existing key.
- Widget tests for model settings screen pass.

## Validation commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/model_settings_screen_test.dart`
