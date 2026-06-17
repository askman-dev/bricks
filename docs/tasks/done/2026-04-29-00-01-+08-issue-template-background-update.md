# Issue Template Background Update

## Background

The repository now has a dedicated issue drafting skill at `.agents/skills/bricks-issue-template/SKILL.md`. Its current template uses separate top-level `Context` and `Motivation` sections.

The implementation plan skill uses a more flexible `Background` section with optional `Context`, `Problem`, and `Motivation` subsections. That structure is a better fit for issue drafting because not every issue needs separate top-level context and motivation sections.

## Goals

- Align the issue template's background structure with the plan template's flexible Background model.
- Replace top-level `Context` and `Motivation` issue sections with a single `Background` section.
- Allow `Context`, `Problem`, and `Motivation` as optional Background subsections.
- Preserve the issue template's `Requirement` and GWT-style `Acceptance Criteria` sections.

## Implementation Plan

1. Update `.agents/skills/bricks-issue-template/SKILL.md` frontmatter to describe the new Background-based structure.
2. Replace the default issue template's top-level `Context` and `Motivation` sections with `Background`.
3. Document optional `Context`, `Problem`, and `Motivation` subsections under `Background`.
4. Update writing rules and checklist language to reference `Background`.

## Acceptance Criteria

- The issue template skill uses `Background`, `Requirement`, and `Acceptance Criteria` as the default top-level issue sections.
- The skill no longer requires top-level `Context` or `Motivation` sections.
- The skill allows optional `Context`, `Problem`, and `Motivation` subsections under `Background`.
- The skill still requires GWT-style acceptance criteria.

## Validation Commands

- `git status --short`
