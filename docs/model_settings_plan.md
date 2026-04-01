# Model Settings Fix and Expansion Plan

## Background
This iteration adds a concrete execution plan and measurable acceptance criteria for the model configuration feature so future work can be tracked and validated consistently.

## Goals
1. Use `gemini-flash-latest` as the default model for Google AI Studio.
2. Ensure save + refresh no longer leads to `Failed to load model settings`.
3. Support `Config 1 / Config 2 / ...` slot-style presentation in the model settings page.
4. Show model names dynamically in slot buttons while storing a stable unique ID decoupled from display names.
5. Keep data structures extensible for multiple slots.

## Implementation Plan

### Phase 1: Default model and persistence reliability
- Normalize the Google AI Studio default model to `gemini-flash-latest` across frontend and backend.
- Make `save` return the server-persisted object and update local state from that response.
- Harden JSON parsing (`Map<dynamic, dynamic>` -> `Map<String, dynamic>`) to avoid runtime parsing failures after refresh.

### Phase 2: Slot-oriented data model
- Introduce `slot_id` in stored config payloads as a stable identifier.
- Add `slotId` to frontend `LlmConfig` and round-trip `slot_id` during save/load.
- Keep `is_default` behavior for backward compatibility with existing default-selection logic.

### Phase 3: Model Settings UI update
- Add a `Configs` row above the Provider selector.
- Compute button labels dynamically from each config’s model name; fallback to `Config N` when empty.
- Preserve API key behavior:
  - New config requires API key.
  - Existing config allows blank API key to keep the current stored key.

### Phase 4: Validation and regression checks
- Pass Flutter static analysis.
- Pass Node backend type checks.
- Manual check: after save, refresh and re-open settings; configuration should load and render correctly.

## Acceptance Criteria
1. For new Google AI Studio configs, the default model is `gemini-flash-latest`.
2. Saving with API key + model ID shows success, and after refresh, model settings load successfully without `Failed to load model settings`.
3. The settings page shows a Config row above Provider with at least one slot; each slot label reflects its model name (or `Config 1` fallback).
4. Stored data includes a stable `slot_id` that is independent from button display names.
5. Code structure supports multiple slots (list state + active slot switching), not a single-config-only object.
6. Validation commands succeed:
   - `flutter analyze`
   - `npm run type-check`

## General verification TODO
- Run `melos analyze` locally and ensure it passes before opening/merging a PR.
- Run `melos test:flutter -- --exclude-tags=integration` locally and ensure it passes before opening/merging a PR.
- Treat analyzer deprecation warnings in touched packages as blocking for the current change.

