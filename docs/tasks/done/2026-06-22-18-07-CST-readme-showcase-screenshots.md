# README Showcase Screenshots

## Background

The README had a placeholder screenshot section. Two product screenshots are available and should be stored in the repository with stable filenames so they render in GitHub Markdown.

## Goals

- Copy the screenshots into a repo-owned asset directory.
- Render both screenshots in the README showcase section.
- Use descriptive filenames and alt text.

## Implementation Plan

1. Copy the chat/channel screenshot to `docs/assets/showcase/chat-knowledge-organization.png`.
2. Copy the resources/highlights screenshot to `docs/assets/showcase/resources-highlights.png`.
3. Replace the README screenshot placeholder with a showcase section.

## Acceptance Criteria

- README renders both screenshots through relative repository paths.
- Screenshot filenames describe the product surface they show.
- No app behavior changes are made.

## Validation Commands

- `sed -n '1,90p' README.md`
