---
name: bricks-issue-template
description: Use when drafting or revising Bricks GitHub issues, product requirements, feature requests, bug reports, or task descriptions that should follow the repository's issue-writing structure. Guides agents to write concise product-facing issues with Context, Motivation, Requirement, and GWT-style Acceptance Criteria, and to avoid implementation details unless explicitly requested.
---

# Bricks Issue Template

Use this skill when the user asks to write, polish, or structure a GitHub issue or product requirement for this repository.

## Default Structure

Use this structure unless the user asks for a different format:

```md
# <short user-facing title>

## Context

<Current situation, relevant product area, and known behavior. Keep it factual.>

## Motivation

<Why this matters to users or maintainers. Explain the user pain or product value.>

## Requirement

<The desired product behavior or capability. Keep display names and stable identities separate when relevant.>

## Acceptance Criteria

- Given <initial context or state>, when <user action or system event>, then <observable expected outcome>.
- Given <initial context or state>, when <user action or system event>, then <observable expected outcome>.
- Given <initial context or state>, when <user action or system event>, then <observable expected outcome>.
```

## Writing Rules

- Write issue drafts in English unless the user explicitly asks for another language.
- Prefer product behavior over implementation details.
- Do not include an `Expected Behavior`, `Implementation Suggestions`, `Technical Plan`, or `How` section unless the user explicitly asks for it.
- Write `Acceptance Criteria` in GWT form: `Given ... when ... then ...`.
- Keep each acceptance criterion testable and user-observable where possible.
- State explicit decisions that were clarified in conversation, such as whether a default item follows the same rule as other items.
- If important scope boundaries exist, add a `Non-goals` section after `Requirement`.
- If the issue is a bug, include the current behavior in `Context` and the corrected behavior in `Requirement`.
- If several terms could be confused, define them in `Context` before using them in criteria.

## Quality Checklist

Before returning the issue draft, check:

- The title describes the outcome, not the implementation.
- `Motivation` explains why the change matters, not just what changes.
- The desired behavior is understandable without reading code.
- Every acceptance criterion follows GWT and can be validated manually or by tests.
- No accidental implementation plan is included by default.
