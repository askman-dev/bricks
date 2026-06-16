# Remove Top Active Agents Indicator Plan

## Background
After the previous UI adjustment, the chat page still renders a top horizontal participant indicator (`_buildActiveAgentsIndicator`) under the AppBar. Product feedback requests removing this list entirely.

## Goals
1. Remove the top participant indicator from the chat page UI.
2. Keep chat routing, sending, and sidebar agent interactions unchanged.
3. Ensure code and tests remain healthy after cleanup.

## Implementation Plan (phased)
### Phase 1: UI cleanup
- Remove AppBar `bottom` usage that mounts `_buildActiveAgentsIndicator`.
- Delete `_buildActiveAgentsIndicator` helper if no longer referenced.

### Phase 2: Validation
- Run Flutter analyze for `chat_screen.dart`.
- Run focused widget tests to ensure no regressions in chat navigation/composer surfaces.

## Acceptance Criteria
- Chat page no longer displays the top horizontal active-agent indicator bar.
- AppBar layout remains stable and chat page renders without runtime/layout errors.
- Analysis/tests for touched chat files pass.
