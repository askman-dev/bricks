# Background
Bricks needs a production-oriented backend interface contract to support OpenClaw plugin development under a pull-only topology. The current design draft captures architectural intent, but it should be hardened into an implementation-ready development document with explicit API contracts, security boundaries, idempotency semantics, and phased delivery guidance. In parallel, the Settings experience in the mobile app should support one-click copy actions for API URL and API key values to reduce operator friction during plugin setup and debugging.

# Goals
1. Produce an improved, implementation-ready Bricks × OpenClaw pull-only integration development document.
2. Define clear backend API boundaries (MVP-required vs optional), auth model, delivery semantics, and operational constraints.
3. Add copy actions in settings for API URL and API key.
4. Add/adjust automated tests for the new settings copy actions.
5. Update code maps if feature/doc index or behavior coverage changes.

# Implementation Plan (phased)
## Phase 1: Documentation hardening
- Create a dedicated integration doc under `docs/` for Bricks platform API + OpenClaw plugin pull-only integration.
- Keep the architecture boundary explicit: Bricks platform vs plugin adapter vs OpenClaw core.
- Add a normative API contract section with request/response shape, error model, idempotency rules, and status code expectations.
- Add implementation sequence, rollout strategy, observability, and security checklist.

## Phase 2: Settings copy UX
- Update `ModelSettingsScreen` to support copying Base URL (API URL) and API key to clipboard.
- Provide user feedback with snackbars for success/empty value cases.
- Preserve existing API key visibility toggle behavior.

## Phase 3: Validation and code-map sync
- Run repository bootstrap command before Flutter checks: `./tools/init_dev_env.sh`.
- Run focused widget tests for settings behavior.
- Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` to reflect the new settings behavior and new integration document indexes.

# Acceptance Criteria
1. A new OpenClaw pull-only integration development document exists under `docs/` and is implementation-ready for backend/API work.
2. Model settings UI exposes a copy action for API URL and a copy action for API key.
3. Tapping copy actions writes expected clipboard values when present and displays user feedback.
4. Existing settings interactions (save/delete/toggle visibility) remain functional.
5. Relevant tests pass (at minimum: `flutter test test/model_settings_screen_test.dart` from `apps/mobile_chat_app`).
6. Code maps are updated to include behavior/doc-index changes introduced by this task.
