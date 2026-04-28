# Change Implementation Plan Skill

## Background

The repository requires implementation plans to be persisted under `docs/plans/`, but the desired plan-writing structure has been refined through discussion.

The plan format should support concise plans for small changes and more structured plans for larger work. `Context`, `Problem`, and `Motivation` should be available as optional Background subsections, not mandatory headings.

## Goals

- Add a reusable skill for implementation plan drafting and persistence.
- Require every implementation plan to be saved under `docs/plans/` with a timestamped filename.
- Standardize plan sections while keeping Background subsections optional.
- Keep validation commands in a dedicated section.

## Implementation Plan

1. Create `.agents/skills/change-implementation-plan/SKILL.md`.
2. Document the purpose of the skill as implementation planning for repository changes.
3. Define the default plan structure and optional Background subsection rules.
4. Capture persistence and validation-command requirements.

## Acceptance Criteria

- The skill exists at `.agents/skills/change-implementation-plan/SKILL.md`.
- The skill name does not include repository-specific branding.
- The skill description explains that it is for implementation plans for repository changes.
- The skill requires plans to be saved under `docs/plans/` with timestamped filenames.
- The skill defines `Context`, `Problem`, and `Motivation` as optional Background subsections.
- The skill requires `Validation Commands` as a dedicated section.

## Validation Commands

- `git status --short`
