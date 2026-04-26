# Background

The repository documentation had strong technical content but weak information architecture for product-facing navigation. The task is to restructure docs into a Docusaurus-friendly layout based only on currently implemented capabilities.

# Goals

1. Reorganize documentation entry points into product-first sections.
2. Keep all content grounded in currently implemented repository state.
3. Avoid roadmap, pricing, or operations planning content.

# Implementation Plan (phased)

## Phase 1: Entry and navigation
- Update `README.md` to point to a clear docs IA.
- Add `docs/intro.md` as the documentation entry page.

## Phase 2: Section pages
- Add product overview page under `docs/product/`.
- Add quickstart page under `docs/get-started/`.
- Add OpenClaw integration summary under `docs/integrations/`.
- Add architecture overview page under `docs/architecture/`.
- Add FAQ page under `docs/faq/`.

## Phase 3: Documentation index alignment
- Update code map `doc_index` references where relevant so new docs are discoverable.

# Acceptance Criteria

1. Repository contains a Docusaurus-friendly docs folder structure with entry page and section pages.
2. `README.md` links users to the new docs structure.
3. New pages describe only currently implemented capabilities/workflows.
4. Code map document indexes include newly introduced docs references where relevant.
