# OpenClaw plugin publish prep skill

## Background

The user wants a reusable repository-local skill that future Codex runs can use
to prepare `apps/node_openclaw_plugin` for public release. The immediate output
should not be the code changes themselves, but a stable skill that captures the
locked product decisions, the release-prep scope, a PRD-style prompt, and the
manual publish steps that a human operator must execute later.

## Goals

- Add a `.codex/skills` entry for OpenClaw plugin public-release preparation.
- Capture the locked product decisions:
  - distribution is npm + ClawHub
  - plugin id remains `dev-askman-bricks`
  - final publish is manual
- Include a PRD-style prompt that can be pasted into Codex.
- Include explicit manual publish and verification commands so the operator does
  not forget them.
- Surface the new skill from `AGENTS.md`.

## Implementation Plan

### Phase 1: Add the skill

- Create `.codex/skills/openclaw-plugin-publish-prep/SKILL.md`.
- Document when to use it, what decisions are locked, and what work is in scope.
- Include the PRD-style prompt inside the skill.

### Phase 2: Surface it in repository guidance

- Update `AGENTS.md` so future agents know to use the new skill first when the
  task is preparing `apps/node_openclaw_plugin` for external release.

### Phase 3: Keep the human handoff explicit

- Write the manual npm publish, ClawHub publish, and clean-install verification
  steps directly into the skill.

## Acceptance Criteria

- A new skill exists at `.codex/skills/openclaw-plugin-publish-prep/SKILL.md`.
- The skill includes a concrete PRD-style prompt.
- The skill explicitly states that final publish remains a manual human step.
- `AGENTS.md` points future agents to the new skill.
