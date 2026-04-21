# OpenClaw plugin refresh skill

## Problem

This repository already has a repeatable workflow for applying updated local
`apps/node_openclaw_plugin` code to a real OpenClaw install, but there is no
dedicated `.codex/skills` entry that captures the repo-specific safe path,
fast path, config refresh path, and verification steps.

## Approach

- Add a new custom skill under `.codex/skills/openclaw-plugin-refresh/`.
- Document the repository-specific facts that matter for this workflow:
  - plugin source location
  - `dist/*` build requirement
  - linked local install path
  - gateway-managed runtime behavior
  - Node version requirement
- Cover both the safe reinstall workflow and the fast path for existing linked
  installs.
- Include the config refresh path and log-based verification steps.
- Surface the new skill from `AGENTS.md` so future agents are more likely to
  discover and use it.

## Validation

- Review the new skill content against:
  - `apps/node_openclaw_plugin/README.md`
  - `apps/node_openclaw_plugin/package.json`
- Verify the new skill path appears under `.codex/skills/`.
- Verify `AGENTS.md` points future agents at the new skill.

## Notes

- This is a documentation/automation-surface change only; no application code
  or runtime behavior should change.
