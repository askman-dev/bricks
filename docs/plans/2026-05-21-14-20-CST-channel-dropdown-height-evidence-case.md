# Channel Dropdown Height Evidence Case

## Background

The top chat channel dropdown can become too tall when many channels exist. The
fix added a popup menu height constraint, but the behavior needs browser
evidence rather than only static code inspection.

## Goals

- Add a case-specific evidence harness following `evidence-case-loop`.
- Verify the current implementation with a real Flutter Web browser run.
- Capture screenshots and numeric checkpoints for menu height and internal
  scrolling.

## Implementation Plan

1. Create `tools/evidence/channel_dropdown_height/` with an `AGENTS.md`
   contract, `run.sh` entrypoint, and Playwright flow script.
2. Ensure the fixture user has enough channel names for the menu to overflow.
3. Open the real app, use test login, click the channel dropdown, capture
   screenshots, measure popup height from image differences, and verify menu
   content scrolls internally.
4. Write evidence to `.cache/evidence/channel-dropdown-height/<run-id>/`.

## Acceptance Criteria

- The harness records `summary.json` with named checks.
- The harness captures before/open/after-scroll screenshots.
- The popup height is bounded below the configured threshold.
- A wheel event changes pixels inside the popup without requiring page scroll.

## Validation Commands

- `tools/evidence/channel_dropdown_height/run.sh`
