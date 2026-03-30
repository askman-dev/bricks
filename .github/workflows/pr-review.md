---
description: |
  Reviews pull requests in the Bricks monorepo and posts inline review comments.
  Analyses changed files for code quality, Dart/Flutter best practices, Node.js
  conventions, and test coverage. Uses the bricks-code-reviewer custom agent for
  domain-specific review criteria.

on:
  pull_request:
    types: [opened, synchronize, ready_for_review]
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: read

engine:
  id: copilot
  agent: bricks-code-reviewer

network: defaults

tools:
  github:
    toolsets: [default]
  bash:
    - "git diff:*"
    - "git log:*"

safe-outputs:
  create-pull-request-review-comment:
    max: 10

timeout-minutes: 10
---

# Bricks PR Review

You are reviewing pull request #${{ github.event.pull_request.number }} in the Bricks monorepo.

**PR title**: "${{ github.event.pull_request.title }}"
**Author**: @${{ github.event.pull_request.user.login }}
**Base branch**: `${{ github.event.pull_request.base.ref }}`

## Your Task

1. Fetch the list of changed files in this PR.
2. Read each changed file (focus on `.dart`, `.ts`, `.tsx`, `.js`, and migration SQL files).
3. Apply the review criteria from the agent instructions.
4. Post inline review comments only for real issues — do not comment on lines that are fine.

## Review Priorities

1. **Blockers** — security issues, null-safety violations, broken migrations, missing `mounted` guards, `undefined` passed as SQL params
2. **Correctness** — logic errors, off-by-one errors, unhandled `async` errors
3. **Convention** — ESM import style (`.js` extensions), Dart Effective Dart rules, missing dartdoc on public APIs
4. **Tests** — new logic without corresponding tests

## Output Format

For each issue found, create a **review comment** on the specific file and line using `create-pull-request-review-comment`.

Each comment should:
- Be concise (2–4 sentences max)
- State what the problem is
- State why it matters
- Suggest the fix

If no issues are found, do not post any comments.
