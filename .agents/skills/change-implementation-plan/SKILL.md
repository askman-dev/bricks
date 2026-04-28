---
name: change-implementation-plan
description: Use when drafting, revising, or persisting an implementation plan for a feature, bug fix, refactor, documentation update, or other repository change. Guides agents to write English plans with Background, Goals, Implementation Plan, Acceptance Criteria, and Validation Commands, and to save every implementation plan under docs/plans/ with a timestamped filename.
---

# Change Implementation Plan

Use this skill when the user asks for an implementation plan, or when repository rules require creating a persisted plan before implementing a feature, bug fix, refactor, documentation update, or other change.

This skill is for implementation planning. Do not use it for GitHub issue drafting, PR summaries, exploratory notes, or post-implementation reports unless the user explicitly asks to convert those into an implementation plan.

## Persistence Rule

Every implementation plan must be saved under `docs/plans/`.

Name the file with a 24-hour timestamp prefix:

```text
YYYY-MM-DD-HH-mm-<short-kebab-title>.md
```

Append a timezone suffix when useful or already established by the repo, for example:

```text
2026-04-28-23-49-+08-sidebar-navigation-simplification.md
```

## Default Structure

Write the plan in English using these sections, in this order:

```md
# <Short Plan Title>

## Background

<Plain background text, or optional subsections when they help.>

### Context

<Optional: current state and relevant existing behavior.>

### Problem

<Optional: limitation, pain point, bug, or gap.>

### Motivation

<Optional: why the change is valuable.>

## Goals

- <High-level objective 1>
- <High-level objective 2>

## Implementation Plan

1. <Phase or step 1>
2. <Phase or step 2>
3. <Phase or step 3>

## Acceptance Criteria

- <Testable and user-observable outcome 1>
- <Testable and user-observable outcome 2>

## Validation Commands

- `<command 1>`
- `<command 2>`
```

## Background Rules

- `Context`, `Problem`, and `Motivation` are optional subsections.
- Use only the subsections that fit the request size and type.
- For small or obvious changes, write direct prose under `Background` without subsections.
- For larger or ambiguous changes, prefer the optional subsections to separate current state, pain points, and value.

## Writing Rules

- Write plans in English unless the user explicitly asks for another language.
- Keep the plan implementation-oriented, not product-marketing-oriented.
- Keep display names and stable storage identities separate when defining extensible configuration systems.
- Include validation commands as their own section, not inside acceptance criteria.
- Make acceptance criteria testable and user-observable where possible.
- Mention when code maps should be updated if the change touches feature entry points, business logic, tests, or docs indexes.
- Avoid implementation trivia in the plan, but include enough phased detail that another agent or human can execute it.

## Quality Checklist

Before returning or saving the plan, check:

- The file is saved under `docs/plans/` with a timestamped filename.
- The plan includes `Background`, `Goals`, `Implementation Plan`, `Acceptance Criteria`, and `Validation Commands`.
- Optional Background subsections are used only when they improve clarity.
- Acceptance criteria describe outcomes, not internal implementation steps.
- Validation commands are relevant to the touched area.
