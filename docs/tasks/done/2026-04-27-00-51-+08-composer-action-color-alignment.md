# Composer Action Color Alignment

## Background
The composer bottom-row controls currently use mixed enabled colors in dark mode: slash, mention, tune, and idle send controls are gray, while active send is near-white. The desired visual direction is that clickable, non-disabled, non-accent controls use the same quiet white-family color unless intentionally highlighted.

## Goals
- Align dark composer bottom action icon/text colors.
- Reuse the existing `AppColors.textPrimary` token without adding new tokens or hardcoded color values.
- Keep the composer controls quiet and avoid brand-blue emphasis.

## Implementation Plan (phased)
1. Update dark `ChatColors.composerActionIdle` and `sendIdle` to map to `AppColors.textPrimary`.
2. Keep active send mapped to `AppColors.textPrimary` so enabled controls are visually consistent.
3. Update code-map smoke coverage for composer bottom controls.
4. Run formatting, focused composer tests, and mobile Flutter analysis.

## Acceptance Criteria
- Slash, mention, tune, and idle send controls use the same dark enabled action color.
- Enabled controls reuse `AppColors.textPrimary`, not brand blue or hardcoded white.
- No new color token is introduced.
