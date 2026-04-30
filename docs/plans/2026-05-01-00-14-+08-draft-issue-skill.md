# Draft Issue Skill

## Background

The repository already has a Bricks-specific issue template skill, but the user also wants the simpler issue-writing structure used in `/Users/admin/CodeSpace/go-puzzle/.agents/skills/draft-issue/SKILL.md`. That structure is useful for concise GitHub issues organized by `Context`, `Problem`, `Goals`, and `Acceptance Criteria`.

## Goals

- Add a reusable repository skill for concise GitHub issue drafting.
- Preserve the existing Bricks-specific issue template skill.
- Make the new skill clear about avoiding implementation plans and validation commands by default.

## Implementation Plan

1. Create `.agents/skills/draft-issue/SKILL.md`.
2. Copy the accepted issue structure into the new skill and adapt wording for this repository.
3. Keep the skill self-contained with no extra references or auxiliary files.

## Acceptance Criteria

- The repository contains a `draft-issue` skill under `.agents/skills/`.
- The skill uses `Context`, `Problem`, `Goals`, and `Acceptance Criteria` in that order.
- The skill tells agents not to include implementation plans or validation commands unless explicitly requested.
- The existing `bricks-issue-template` skill remains unchanged.

## Validation Commands

- `git diff --check`
