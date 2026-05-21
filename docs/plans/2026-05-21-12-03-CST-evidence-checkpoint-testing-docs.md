# Evidence Checkpoint Testing Docs

## Background

The channel New UI harness proved useful because it tested the same path a user
uses in the product, while also checking the API and database state behind that
visible result. The reusable lesson is not specific to channels: browser
evidence is most useful when it is paired with scoped data checkpoints and an
explicit test identity.

## Goals

- Document the reusable local browser plus API plus database checkpoint pattern.
- Make the fixture-user boundary explicit so cloud database rows are not
  confused with rows for a different production user.
- Link the concrete channel New UI harness to the general testing pattern.
- Keep code maps aligned with the new testing documentation.

## Implementation Plan

1. Add a reusable testing note under `docs/testing/` that describes the
   environment shape, checkpoint layers, artifact naming, and failure reading.
2. Update the channel New UI harness README to link to the general note and
   explain that cloud Turso rows are scoped to `FIXTURE_USER_ID`.
3. Update code maps so future agents can discover the general testing note from
   the backend/runtime evidence entry.

## Acceptance Criteria

- The documentation explains why the harness can write a row that is not visible
  to another logged-in production user.
- The documentation describes UI, API, and direct database checkpoints in a
  reusable way.
- The channel harness README points to the reusable documentation.
- YAML code maps remain parseable.

## Validation Commands

- `npx js-yaml docs/code_maps/feature_map.yaml >/dev/null`
- `npx js-yaml docs/code_maps/logic_map.yaml >/dev/null`
