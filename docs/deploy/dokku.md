# Dokku Deployment

This deployment runs one Bricks instance per Dokku app. Each app mounts one
channel data root into the same container path:

```text
/app/data/channels
```

Production host data:

```text
/home/bricks/data/production/channels
```

Preview host data:

```text
/home/bricks/data/previews/<branch-slug>/channels
```

## Production App

```sh
dokku apps:create bricks
mkdir -p /home/bricks/data/production/channels
dokku storage:mount bricks /home/bricks/data/production/channels:/app/data/channels
dokku domains:set bricks craft.bricks.cool
dokku letsencrypt:enable bricks
```

Set required config values without committing secrets:

```sh
dokku config:set bricks \
  NODE_ENV=production \
  TRUST_PROXY=true \
  BRICKS_STATIC_ROOT=/app/public \
  BRICKS_CHANNEL_ROOT=/app/data/channels \
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

Each PR preview app uses a separate Dokku app and a separate host data root.
The GitHub Actions workflow computes the branch slug and deploys to:

```text
https://<branch-slug>.craft-dev.bricks.cool
```

The preview keeps `GITHUB_CALLBACK_URL=https://craft.bricks.cool/api/callback`
so GitHub always returns to production, then production redirects back to the
validated preview `return_to` URL.
