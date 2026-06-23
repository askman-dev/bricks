# Bricks Local Cloud Dev Skill

## Background

Manual UI, style, and interaction work often needs the real Bricks app running
locally against realistic cloud data. The existing evidence-oriented browser
skill covers proof collection, but this workflow needs a separate agent skill
focused on local development startup and safe hand-off to a human tester.

## Goals

- Add a dedicated skill for local backend + cloud Turso + local Flutter Web.
- Document Quick Login via `BRICKS_TEST_TOKEN` without storing or exposing
  secrets.
- Keep cloud database safeguards explicit, especially `AUTO_MIGRATE=false`.

## Implementation Plan

1. Create `.agents/skills/bricks-local-cloud-dev/SKILL.md`.
2. Include startup commands for the local Node backend and Flutter Web frontend.
3. Reference `.env.local` as the secret source without printing values.
4. Include verification and troubleshooting notes for Quick Login and cloud DB
   safety.

## Acceptance Criteria

- The skill is discoverable from its frontmatter description when the user asks
  to start a local development environment against cloud data.
- The skill does not contain any secret values or remote auth tokens.
- The skill clearly distinguishes manual development from automated evidence
  testing.
- The skill instructs agents to force `AUTO_MIGRATE=false` when using cloud
  Turso.

## Validation Commands

- `sed -n '1,220p' .agents/skills/bricks-local-cloud-dev/SKILL.md`
- `rg -n "BEGIN PRIVATE KEY|sk-" .agents/skills/bricks-local-cloud-dev docs/plans/2026-06-23-15-17-CST-bricks-local-cloud-dev-skill.md`
