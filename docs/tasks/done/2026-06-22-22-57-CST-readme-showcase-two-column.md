# README Showcase Two-Column Layout

## Background

The README Showcase section displayed two screenshots as stacked subsections.

## Goals

- Show the two showcase screenshots in one row with two columns.
- Keep the screenshot labels and alt text readable in GitHub Markdown.

## Implementation Plan

1. Replace the stacked screenshot subsections with a two-column Markdown table.
2. Keep the existing screenshot asset paths unchanged.

## Acceptance Criteria

- The README Showcase section renders both screenshots in one table row.
- The two columns retain meaningful labels.
- No app behavior changes are made.

## Validation Commands

- `sed -n '20,42p' README.md`
