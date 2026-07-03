# README Resource Copy

## Background

Bricks resources are a differentiating product area because the app turns chat output into durable workspace objects instead of leaving everything inside a linear conversation. The README should explain each resource type with a short description and practical use cases.

## Goals

- Add a dedicated resource section to the README.
- Describe each current resource type in product-facing language.
- Include concrete use cases for each resource.
- Keep roadmap-only resource ideas separate from shipped resources.

## Implementation Plan

1. Add a `Resources` section after `What Bricks does today`.
2. List Todo Lists, Tables, Notes, and Highlights with descriptions and use cases.
3. Keep the existing screenshot, roadmap, documentation, docs site, and setup sections intact.

## Acceptance Criteria

- README explains why resources matter to Bricks.
- README lists each current resource type with use cases.
- README does not present roadmap-only ideas as shipped features.
- No source code behavior changes.

## Validation Commands

- `sed -n '1,180p' README.md`
