# Preview Site Storage and Database Isolation

## Background

Channel-generated websites currently store site metadata in the shared database
while website files live on the filesystem mounted for the running Dokku app.
Production and each PR preview app use isolated filesystem roots, but preview
apps currently share the same Turso database configuration copied from
production.

This creates a mismatch for generated site preview URLs. A preview app can write
a `channel_sites` row and generate a public slug, but a different app resolving
the same database row cannot necessarily read the corresponding `web/dist`
files, because those files exist only under the filesystem root of the app that
built them.

The visible symptom is that a production-style URL such as:

```text
https://s-<slug>.craft-spaces.bricks.cool
```

cannot safely resolve preview content unless the request is routed to the exact
preview app whose filesystem contains that slug's build output. The slug alone
does not encode the preview app identity, so a global `*.craft-spaces.bricks.cool`
host cannot know which preview filesystem to use.

## Requirement

Design and implement a product-level solution for preview generated-site
hosting that keeps production and PR preview data isolated across both database
metadata and filesystem build outputs.

The solution must make it possible to resolve a generated site's metadata and
its files from the same environment boundary, instead of reading slug metadata
from one shared DB and trying to serve files from another app's isolated disk.

## Acceptance Criteria

- Production generated sites continue to support stable public URLs under
  `*.craft-spaces.bricks.cool`.
- PR preview generated sites have an environment-aware URL and routing model
  that can find the matching preview filesystem.
- A preview app must not read or serve production generated-site files.
- Production must not accidentally serve preview-only build outputs.
- The database strategy is explicit: either preview uses an isolated DB/branch,
  or site metadata records include enough environment identity to route to the
  correct storage boundary.
- The filesystem strategy is explicit: either a central gateway can access the
  correct build output safely, or each preview site URL routes directly to the
  preview app that owns the files.
- A stale or cross-environment slug must fail closed rather than serving another
  environment's content.
- The chosen design documents how `channel_sites.public_slug`, `web/dist`, and
  PR preview app identity relate to each other.

## Non-Goals

- Do not implement this in the current slice.
- Do not rely on manually adding one Dokku domain per generated preview slug as
  the long-term solution.
- Do not make preview apps share the production filesystem root.
