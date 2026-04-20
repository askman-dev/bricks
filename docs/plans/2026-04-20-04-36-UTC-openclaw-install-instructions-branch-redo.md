## Background

The previous implementation already added OpenClaw install instructions and copy support, but follow-up iteration is required on a new branch and with cleaner test interaction stability.

## Goals

1. Continue implementation work on a new branch name.
2. Keep the install-instructions UX behavior unchanged.
3. Improve widget-test reliability by avoiding long fixed-time waits.

## Implementation Plan (phased)

### Phase 1: Branch and test refinement

- Create and use a new working branch for this follow-up.
- Update `openclaw_token_settings_screen_test.dart` to dismiss snackbars deterministically before the second copy action.

### Phase 2: Validation

- Run repository bootstrap script.
- Run focused Flutter widget tests for Openclaw token settings.

### Phase 3: Documentation sync

- Add this plan artifact for the task record.
- Keep code-map files unchanged if behavior/entry points do not change.

## Acceptance Criteria

1. Work is delivered from a non-previous branch.
2. Install-instructions copy behavior and token copy behavior both pass tests.
3. No user-visible behavior regression on Openclaw token settings page.
