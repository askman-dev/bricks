## Background
Reviewer feedback requested checking current code implementation and ensuring the OpenClaw pull-only integration document stays aligned with actual backend behavior and boundaries.

## Goals
1. Verify whether current backend storage patterns conflict with the integration document.
2. Update the document where needed so it clearly distinguishes current implementation status vs target OpenClaw contract.
3. Keep changes minimal and scoped to the feedback.

## Implementation Plan (phased)
- [x] Inspect current backend chat storage schema and transport services.
- [x] Compare current implementation with the OpenClaw integration document data-model guidance.
- [x] Update `docs/openclaw_pull_only_integration_dev_doc.md` with explicit implementation-alignment notes.
- [ ] Validate changed docs and reply on PR thread with commit reference.

## Acceptance Criteria
- The document explicitly states that message storage remains unified (not split by message source).
- The document explicitly states that event/outbox persistence is an independent concern and currently a target integration contract.
- PR thread receives a concise follow-up with the commit hash that contains the alignment update.
