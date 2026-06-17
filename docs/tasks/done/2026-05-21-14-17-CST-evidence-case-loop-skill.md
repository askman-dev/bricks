# Evidence Case Loop Skill

## Background

The existing `evidence-driven-browser-test-env` skill describes how to gather
browser, API, database, screenshot, and secret-safe evidence. A separate
case-level workflow is useful for stubborn bugs: create a dedicated evidence
case directory, prove the bug with baseline evidence, fix code, then rerun the
same path to prove the fix.

## Goals

- Add a concise repo skill for the case-level evidence loop.
- Keep browser startup, screenshots, auth bypass, API/DB checks, and secret
  handling delegated to `evidence-driven-browser-test-env`.
- Standardize the per-case directory contract around `AGENTS.md`, `run.sh`,
  flow scripts, checkpoint scripts, and `summary.json`.

## Implementation Plan

1. Create `.agents/skills/evidence-case-loop/SKILL.md`.
2. Define the skill trigger, dependency boundary, case directory shape, loop
   steps, evidence output convention, and final reporting expectations.
3. Keep the skill self-contained and avoid auxiliary README files.

## Acceptance Criteria

- The skill clearly says it does not decide when evidence is required.
- The skill explicitly references `evidence-driven-browser-test-env` for
  browser/environment mechanics.
- The skill requires baseline-before-fix and rerun-after-fix evidence.
- The skill uses `AGENTS.md`, not `README.md`, as the case contract.

## Validation Commands

- `test -f .agents/skills/evidence-case-loop/SKILL.md`
- `sed -n '1,220p' .agents/skills/evidence-case-loop/SKILL.md`
