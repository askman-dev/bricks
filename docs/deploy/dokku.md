# Dokku Deployment

This deployment runs one Bricks instance per Dokku app. Each app mounts one
per-user sandbox data root into the same container path:

```text
/app/data/sandboxes
```

Production host data:

```text
/home/bricks/data/production/sandboxes
```

Preview apps intentionally use the same production host data root while they
share the production database:

```text
/home/bricks/data/production/sandboxes
```

## Production App

```sh
dokku apps:create bricks
mkdir -p /home/bricks/data/production/sandboxes
dokku storage:mount bricks /home/bricks/data/production/sandboxes:/app/data/sandboxes
dokku domains:set bricks craft.bricks.cool craft-spaces.bricks.cool '*.craft-spaces.bricks.cool'
dokku letsencrypt:enable bricks
```

Generated channel sites use stable wildcard hosts such as
`https://s-abc123.craft-spaces.bricks.cool/`. The production app must keep both
`craft-spaces.bricks.cool` and `*.craft-spaces.bricks.cool` bound to the same
Dokku app so future site slugs route without per-site domain changes. Cloudflare
edge certificates cover the browser-to-Cloudflare hop; the Dokku origin must
also accept the wildcard SNI for Cloudflare-to-origin TLS.

Install the same-host sandbox runner before enabling AI shell execution:

```sh
cd /path/to/bricks
RUNNER_TOKEN="<shared-runner-token>" \
  SANDBOX_ROOT=/home/bricks/data \
  RUNNER_HOST=172.17.0.1 \
  RUNNER_PORT=8787 \
  sudo -E tools/sandbox_runner/install_vultr.sh
```

The installer registers Docker's `runsc` runtime, starts the
`bricks-sandbox-runner` systemd service, and, when UFW is active, allows only
Docker bridge traffic from `172.17.0.0/16` to `172.17.0.1:8787`. Do not expose
the runner port on the public network. The runner root must be the shared host
data root. Production and preview currently share the same database and channel
IDs, so both environments use `production,sandboxes` as the runner root
segments and mount the same workspace root.

Set required config values on the Dokku server without committing secrets.
Runtime secrets such as Turso credentials, JWT signing keys, and encryption keys
must stay in Dokku config on the server; do not store them in GitHub Actions
secrets for this open-source repository.

```sh
dokku config:set bricks \
  NODE_ENV=production \
  TRUST_PROXY=true \
  BRICKS_STATIC_ROOT=/app/public \
  BRICKS_SANDBOX_ROOT=/app/data/sandboxes \
  BRICKS_SANDBOX_RUNNER=http \
  BRICKS_SANDBOX_RUNNER_URL=http://172.17.0.1:8787 \
  BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS=production,sandboxes \
  BRICKS_SANDBOX_RUNNER_TOKEN="<shared-runner-token>" \
  GITHUB_CALLBACK_URL=https://craft.bricks.cool/api/callback \
  OAUTH_ALLOWED_RETURN_ORIGINS=https://craft.bricks.cool \
  TURSO_DATABASE_URL=... \
  TURSO_AUTH_TOKEN=... \
  GITHUB_CLIENT_ID=... \
  GITHUB_CLIENT_SECRET=... \
  JWT_SECRET=... \
  ENCRYPTION_KEY=... \
  CRON_SECRET=... \
  GEMINI_API_KEY=... \
  ANTHROPIC_API_KEY=...
```

## Preview Apps

Each PR preview app uses a separate Dokku app. Because previews currently share
the production database and channel IDs, they also mount the production sandbox
root so site workspace files are consistent across production and preview.
The GitHub Actions workflow computes the branch slug and deploys to:

```text
https://<branch-slug>.craft-dev.bricks.cool
```

The preview keeps `GITHUB_CALLBACK_URL=https://craft.bricks.cool/api/callback`
so GitHub always returns to production, then production redirects back to the
validated preview `return_to` URL.

Preview apps copy `TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN`, `JWT_SECRET`, and
`ENCRYPTION_KEY` from the production Dokku app on the server during deployment,
so those values do not leave the server through GitHub Actions.

When a pull request is closed, the preview workflow destroys the matching
`bricks-preview-*` Dokku app. Because preview apps mount
`/home/bricks/data/production/sandboxes`, cleanup must preserve that shared
production data root.
