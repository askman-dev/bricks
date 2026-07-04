# Preview Site Shared Storage and Production Readiness

## Background

Channel-generated websites currently store site metadata in the shared database
while website files live under the shared production sandbox filesystem mounted
for the running Dokku app.

Production and each PR preview app intentionally share the same Turso database
configuration and the same sandbox workspace root:

```text
/home/bricks/data/production/sandboxes
```

This keeps `channel_sites.public_slug`, channel workspace files, and `web/dist`
build output inside the same operational boundary for both production and PR
preview apps.

The visible risk is not environment isolation. The risk is that deployment
configuration, cleanup, and static serving must match the shared-root design:

```text
https://s-<slug>.craft-spaces.bricks.cool
```

must resolve through the shared `channel_sites` row and the shared `web/dist`
files without transient static asset failures surfacing as backend 500s.

## Requirement

Verify and harden the production/preview deployment model for generated site
hosting:

- Dokku app/config/data root values must match the intentional shared database
  and shared workspace design.
- Preview close/merge cleanup must remove the preview Dokku app without deleting
  the shared production sandbox data root.
- Production and preview GitHub OAuth return flows must remain valid with the
  production callback and preview `return_to` redirect.
- Generated site static serving must fail closed with a controlled not-published
  response rather than a backend 500 when a dist asset disappears during a build
  or deploy race.

## Acceptance Criteria

- Production generated sites continue to support stable public URLs under
  `*.craft-spaces.bricks.cool`.
- PR preview apps use the production Turso credentials and mount
  `/home/bricks/data/production/sandboxes` into `/app/data/sandboxes`.
- PR preview apps set `BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS=production,sandboxes`
  so shell/build commands operate on the shared workspace root.
- PR close/merge cleanup destroys only the matching `bricks-preview-*` Dokku app
  when `DATA_ROOT=/home/bricks/data/production/sandboxes`.
- Production keeps `GITHUB_CALLBACK_URL=https://craft.bricks.cool/api/callback`
  and preview return URLs under `https://<branch-slug>.craft-dev.bricks.cool`
  remain allowlisted.
- A generated site request for an asset that disappears during read returns
  `404 Site not published` with `X-Robots-Tag: noindex`, not a backend 500.
- Code maps and deployment docs describe the shared-root production/preview
  model accurately.

## Non-Goals

- Do not split preview DB or workspace storage in this slice.
- Do not delete production shared workspace data when cleaning up PR previews.
