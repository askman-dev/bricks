# Design System Skill

## Background
The color/theme KB now defines a surface-layer-first approach. Future Codex runs need a repository-local skill that reminds agents to use that model before modifying UI colors, adding tokens, or changing chat surfaces.

## Goals
- Add a repository-local design-system skill under `.codex/skills/`.
- Make the skill route agents to `docs/kb/color-theme-architecture.md` before color/theme edits.
- Capture the current token decision rules: reuse core layers first, add component aliases sparingly, and keep docs/code maps aligned.

## Implementation Plan (phased)
1. Create `.codex/skills/bricks-design-system/SKILL.md`.
2. Document the inspection workflow for token/theme/UI color changes.
3. Include guardrails for redundant tokens, responsive surface roles, and validation.
4. Add the new skill to the relevant code-map documentation index.

## Acceptance Criteria
- A new Codex skill exists for Bricks design-system work.
- The skill instructs agents to read the color/theme KB before design-token edits.
- The skill encodes the surface-layer-first rule and component-alias criteria.
- The code maps reference the new skill where design-system docs are indexed.
