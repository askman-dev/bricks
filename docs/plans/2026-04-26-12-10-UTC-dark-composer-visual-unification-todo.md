# Dark Mode Composer Visual Unification — Code-Fit TODO Plan

## Background
The current dark-mode chat UI already has a design-system foundation (`AppColors`, `ChatColors`) but key composer and status visuals are still inconsistent with a premium minimal style:

- Accent blue is overused for non-critical controls (e.g., `/`, `@`, send icon, stop button backgrounds).
- Colored emoji (`🦞`) is used as a delivery/status icon in multiple places.
- Agent attribution text/icon color and composer action colors are not separated by semantic intent.
- Composer container sizing/padding leaves a “large console” impression instead of a compact ChatGPT/X-like composer.

In addition, there is token-level redundancy/ambiguity:

- `AppColors` has legacy aliases (`surface`, `surface2`, `surface3`, etc.) that can mask semantic intent.
- `ChatColors` currently mixes interaction accent and identity accent into `agentAccent`.

## Goals
1. Keep dark mode minimal and premium by converging action icon colors to a white/gray scale.
2. Restrict blue accent to true state/activation semantics only.
3. Remove colorful emoji from production chat/status UI.
4. Reduce composer default visual weight (height/padding/button emphasis) while keeping usability.
5. Land changes in a way that matches existing code structure and tests, avoiding disruptive refactors.

## Implementation Plan (phased)

### Phase 1 — Token cleanup and semantic expansion (design system first)
- Add explicit chat token roles to `ChatColors` so interaction states do not overload `agentAccent`:
  - `composerActionIdle`
  - `composerActionHoverOrPressed`
  - `composerActionDisabled`
  - `sendIdle`
  - `sendActive`
  - `agentIdentity` (replace current visual meaning of `agentName` in dark mode)
  - `statusRunning` / `statusCompleted` (if needed, can map to existing semantic colors)
- Keep existing fields temporarily with deprecation comments to avoid immediate breakage.
- Map dark defaults to neutral white-gray scale; reserve accent blue only for activated/explicit state cues.

### Phase 2 — ComposerBar visual convergence
- In `composer_bar.dart`:
  - Replace `/` and `@` trigger text colors from `chatColors.agentAccent` to neutral token (`composerActionIdle`).
  - Replace config/tune icon, send icon, and stop control with state-driven neutral/active mapping:
    - Empty input -> `sendIdle` (neutral)
    - Non-empty input -> `sendActive` (clear active cue)
    - Disabled -> `composerActionDisabled`
  - Introduce `ValueListenableBuilder`/controller listener for input non-empty state to drive send visual activation.
  - Reduce composer perceived height:
    - lower vertical paddings
    - slightly smaller action tap target visuals (without violating minimum hit area)
    - cap multiline expansion more tightly (e.g., keep `maxLines: 4` unless product requires 5)

### Phase 3 — Status icon and agent attribution de-colorization
- In `message_list.dart` and `chat_screen.dart`:
  - Replace lobster emoji delivery indicators and router emoji entry with monochrome icon(s) (custom glyph or Material icon fallback).
  - Move assistant attribution icon/text color to neutral `agentIdentity` token.
  - Keep blue only for explicit “running/active route selected” states when needed.

### Phase 4 — Redundancy hardening and migration safety
- Audit call sites still directly relying on overloaded accent tokens and migrate to new semantic tokens.
- Add comments to legacy aliases in `AppColors` and create a follow-up cleanup issue for alias removal.
- Ensure theme extension fallback behavior remains stable for tests running plain `MaterialApp`.

### Phase 5 — Validation and regression coverage
- Update/add widget tests in `composer_bar_test.dart` and `message_list` related tests to assert:
  - neutral default send icon state
  - activated send visual state only when input has content
  - no lobster emoji rendered in delivery/status UI
  - composer menu/actions disabled states remain correct

## Acceptance Criteria
1. In dark mode, bottom composer action controls use a consistent white/gray hierarchy in idle state.
2. Send control is not permanently highlighted; it visibly enters active state only when input is non-empty.
3. No colorful emoji is used for delivery/router status UI in chat surfaces.
4. Agent name/icon in message attribution no longer uses bright blue in idle identity display.
5. Composer appears visually more compact than before while retaining accessibility and functional parity.
6. Existing composer behavior tests pass; new state-color behavior tests pass.

## Validation Commands
- `./tools/init_dev_env.sh`
- `cd apps/mobile_chat_app && flutter test test/composer_bar_test.dart`
- `cd apps/mobile_chat_app && flutter test test/message_list_test.dart`
