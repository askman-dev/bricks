# Evidence-Driven Browser Test Environment Skill

## Background

Some UI defects cannot be validated confidently through unit tests alone. They
depend on realistic data, historical state variety, browser rendering, scroll
position, user-triggered interactions, asynchronous updates, and screenshot
evidence.

The repository needs a reusable agent skill that tells future agents how to
construct a trustworthy local or CI validation environment before fixing these
types of issues.

## Goals

- Add a repository skill that guides data-backed browser validation work.
- Make the workflow explicit about fixture data, local auth bypasses, real
  browser interactions, screenshots, and safe persistence rules.
- Keep the skill general enough for future complex UI/data tasks, not only the
  current chat scroll issue.

## Implementation Plan

1. Create `.agents/skills/evidence-driven-browser-test-env/SKILL.md`.
2. Define clear trigger conditions for data-dependent, browser-rendered, or
   interaction-triggered behavior.
3. Document a practical workflow for building local fixture-backed environments.
4. Document evidence requirements and failure checks.
5. Document what should and should not be committed to Git.

## Acceptance Criteria

- The new skill exists under `.agents/skills/`.
- The skill describes when to use it and how to validate interaction-triggered
  browser behavior.
- The skill explicitly separates safe committed artifacts from local-only or
  sensitive artifacts.
- Future agents can use the skill without needing context from this chat.

## Validation Commands

- `test -f .agents/skills/evidence-driven-browser-test-env/SKILL.md`
- `sed -n '1,240p' .agents/skills/evidence-driven-browser-test-env/SKILL.md`
