# Background
The model settings page currently provides only a Save action, which makes it impossible to remove an existing model configuration directly from the form actions.

# Goals
- Add a Delete button on the model settings page.
- Ensure Delete appears to the left and Save appears to the right.
- Implement delete behavior for persisted configs, with safe handling for unsaved configs.
- Keep validation and save behavior unchanged.

# Implementation Plan (phased)
1. **Service support**
   - Add a `deleteConfig` method in `LlmConfigService` that sends `DELETE /api/config/{id}` with auth headers.
2. **UI and interaction**
   - Add `_deleteCurrentConfig` method in `ModelSettingsScreen`.
   - For persisted configs (`id != null`), prompt for confirmation and call the service delete API.
   - For unsaved local configs (`id == null`), remove locally without API call.
   - Keep at least one editable config by creating a blank default if all configs are removed.
3. **Action layout**
   - Replace the single Save button with a horizontal row:
     - Delete button on the left.
     - Save button on the right.
4. **Validation checks**
   - Run environment bootstrap and at least one Dart/Flutter check command.

# Acceptance Criteria
- Model settings page shows both actions with Delete on the left and Save on the right.
- Tapping Delete removes the active config (with confirmation for persisted configs).
- Save continues to persist the active config as before.
- Validation command(s) complete successfully (for example: `flutter analyze`, `flutter test`).
