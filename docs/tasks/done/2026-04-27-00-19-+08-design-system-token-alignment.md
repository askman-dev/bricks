# Design System Token Alignment

## Background
The current color KB emphasizes component-level tokens, while the latest chat dark-mode work uses a smaller surface-layer model inspired by ChatGPT: base/chrome/recessed/elevated surfaces with thin component aliases. Code and documentation need to describe the same model.

## Goals
- Identify redundant or stale color token definitions.
- Update the color KB so it matches the intended surface-layer-first design.
- Keep useful component aliases where they improve readability.
- Remove unused token definitions that encourage over-specific naming.

## Implementation Plan (phased)
1. Audit actual token usage in `AppColors`, `ChatColors`, and chat widgets.
2. Remove unused legacy aliases and unused `ChatColors` fields.
3. Revise `docs/kb/color-theme-architecture.md` to define the surface-layer-first rule.
4. Run formatting and Flutter analysis.
5. Check whether code maps need an update because the KB/design-token index changed.

## Acceptance Criteria
- The KB says to prefer existing surface/text/border/accent/status layers before adding component tokens.
- Code no longer exposes unused `BricksColorTokens`, legacy aliases, or unused `ChatColors` fields.
- Existing chat UI behavior remains unchanged.
- Validation includes `dart format` and `flutter analyze`.
