# Bricks Issue Template Skill

## Background

The repository has project-specific skills under `.agents/skills/`, but no GitHub issue template was found under `.github/ISSUE_TEMPLATE`. Product requirement discussions still need a consistent structure for issue drafts.

## Goals

- Add a repository skill that helps agents draft Bricks GitHub issues using a consistent product-facing structure.
- Include Context, Motivation, Requirement, and Acceptance Criteria sections.
- Require Acceptance Criteria to use GWT form.
- Keep implementation details out of the default issue body unless the user explicitly asks for them.

## Implementation Plan (phased)

1. Create `.agents/skills/bricks-issue-template/SKILL.md`.
2. Document the trigger conditions and issue structure.
3. Keep the skill concise and self-contained so it can be loaded cheaply.

## Acceptance Criteria

- The new skill exists at `.agents/skills/bricks-issue-template/SKILL.md`.
- The skill frontmatter includes a clear `name` and `description`.
- The skill instructs agents to use Context, Motivation, Requirement, and Acceptance Criteria.
- The skill requires GWT-style acceptance criteria.
- The default issue template avoids implementation suggestions unless requested.
