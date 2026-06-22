# README Feature Copy

## Background

The README opening currently lists only a few capabilities and does not clearly separate shipped Bricks features from future roadmap ideas. The product positioning line "The agent console for tinkerers." should remain.

## Goals

- Keep the opening tagline.
- Add a `What Bricks does today` section for currently implemented product capabilities.
- Add a screenshots area that can receive images later.
- Add a roadmap section that is clearly future-facing.

## Implementation Plan

1. Rewrite the README opening bullets under a new `What Bricks does today` heading.
2. Add a `Screenshots` placeholder section without committing image assets.
3. Add a short `What's on the roadmap` section for known future directions.
4. Leave setup and documentation links unchanged.

## Acceptance Criteria

- README keeps "The agent console for tinkerers."
- README includes `## What Bricks does today`.
- README includes a screenshot placeholder section.
- README includes a roadmap section separate from shipped features.
- No source code behavior changes.

## Validation Commands

- `sed -n '1,140p' README.md`
