# PR 286 Code Review Fixes

## Background

PR 286 implements composer paste image support, Shift+Enter newlines, editable todo resources, and editable note resources. A follow-up review should catch regressions before the PR is ready for merge.

## Requirement

Review the implementation and fix issues that could break lifecycle safety, resource editing UX, or the recorded task acceptance criteria.

## Acceptance Criteria

- Pasted image callbacks do not trigger parent upload state after the composer or page is disposed.
- Todo and note edit failures keep the current editable content visible.
- The note editor exposes lightweight Markdown editing controls and a preview mode.
- Focused widget tests and analyzer checks pass after the fixes.
