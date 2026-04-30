---
name: draft-issue
description: Use when drafting, writing, revising, or creating GitHub issues that should use a concise issue structure with Context, Problem, Goals, and Acceptance Criteria. Guides agents to keep issues outcome-focused and avoid implementation plans or validation commands unless explicitly requested.
---

# Draft Issue

Use this skill when the user asks to draft, write, revise, or create a GitHub issue.

This skill is for issue drafting only. Do not use it for implementation plans, PR summaries, or post-implementation reports.

## Default Structure

Write the issue in the same language the user is using unless they explicitly ask for another language. Use these four sections, in this order:

```md
## Context

<Current state: what exists today, what the user or system is doing, and any relevant background.>

## Problem

<The limitation, pain point, bug, or gap that motivates this issue.
Be specific: what breaks, what is missing, or what is confusing.>

## Goals

- <What this issue should achieve, from the user's or system's perspective.>
- <Add one bullet per distinct goal. Keep goals high-level, not implementation steps.>

## Acceptance Criteria

- <A testable or user-observable outcome that must be true when this issue is resolved.>
- <Add one bullet per criterion.>
```

## Writing Rules

- Keep each section short and direct. Omit filler sentences.
- `Context` describes current reality, not the desired future state.
- `Problem` explains why the current reality is insufficient. One paragraph is usually enough.
- `Goals` are outcome-oriented, not task lists. Avoid "implement X"; prefer "user can do Y".
- `Acceptance Criteria` must be verifiable. Prefer observable behavior over internal implementation details.
- Do not add an Implementation Plan, Validation Commands, Motivation, or Technical Approach section unless the user explicitly asks.
- Include branch names, plan paths, linked PRs, or source documents in `Context` when the user says implementation should reference them.
- If the user asks you to create the issue on GitHub, draft the body first, then create the issue with the GitHub CLI or available GitHub tool.

## Quality Checklist

Before returning or creating the issue, check:

- All four sections are present: `Context`, `Problem`, `Goals`, `Acceptance Criteria`.
- `Context` and `Problem` are distinct: Context is current state; Problem is why it is insufficient.
- Goals describe outcomes, not implementation steps.
- Every acceptance criterion is testable or user-observable.
- The draft is concise and has no repeated content across sections.
