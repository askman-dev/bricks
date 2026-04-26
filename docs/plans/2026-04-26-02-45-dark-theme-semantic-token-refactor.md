# Background
The chat UI dark theme currently mixes direct `ColorScheme` fields and hard-coded color values, which causes inconsistent hierarchy across user bubbles, assistant text, composer UI, and metadata. The design direction requires an X-style dark palette with semantic token usage so product surfaces remain neutral while brand blue is reserved for actionable states.

# Goals
1. Introduce a semantic dark color token set aligned with the provided palette (pure black base, grayscale surfaces, single brand blue, isolated status colors).
2. Ensure chat components consume semantic tokens instead of raw colors or misused `colorScheme.primary` for non-brand surfaces.
3. Update key components (message list + composer) to reflect the new visual hierarchy in dark mode.
4. Keep code-map docs synchronized for changed feature logic/index references.

# Implementation Plan (phased)
## Phase 1: Token foundation
- Update `packages/design_system/lib/src/tokens.dart` with semantic palette constants (background/surface/border/text/accent/status).
- Expand `packages/design_system/lib/src/chat_colors.dart` semantic fields to cover message/composer/meta/link/badge roles.
- Update `packages/design_system/lib/src/bricks_theme.dart` dark `ColorScheme` to keep Material base semantics minimal and consistent with the new palette.

## Phase 2: Chat UI migration
- Refactor `apps/mobile_chat_app/lib/features/chat/widgets/message_list.dart` to consume updated `ChatColors` semantics for:
  - user bubble/background/text/meta
  - assistant text/meta/accent
  - badge/pill styling
  - markdown inline link color and code/quote container styling
- Refactor `apps/mobile_chat_app/lib/features/chat/widgets/composer_bar.dart` to use semantic composer colors for container, border, placeholder, and send/stop actions.

## Phase 3: Validation and docs
- Run environment bootstrap and targeted Flutter checks.
- Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` to reflect token/theme and chat widget mapping changes.
- Verify YAML format and summarize regression-smoke focus.

# Acceptance Criteria
- Dark mode uses black background + grayscale surfaces + single accent blue for interactive emphasis.
- User message bubble no longer uses Material `primary`; it uses semantic message container tokens.
- Meta text (time/thread/handle-like info) uses a unified secondary token.
- Composer default border is subtle, with stronger emphasis only on focus/action states.
- Business widgets avoid raw hex colors and direct color misuse for chat hierarchy.
- Validation commands complete successfully: `./tools/init_dev_env.sh`, `cd apps/mobile_chat_app && flutter analyze`, and `python3 -c "import yaml..."` for code maps.
