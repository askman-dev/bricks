# Craft Spaces Wildcard Origin TLS

## Background

Published channel sites use canonical URLs under
`https://<slug>.craft-spaces.bricks.cool/`. Cloudflare edge certificates cover
`*.craft-spaces.bricks.cool`, but requests currently fail before reaching the
Bricks backend because the Dokku origin only knows `craft.bricks.cool`.

## Goals

- Configure the production Dokku origin to accept `craft-spaces.bricks.cool`
  and `*.craft-spaces.bricks.cool`.
- Install or document the required origin TLS certificate for wildcard site
  hosts.
- Verify that a published site such as
  `https://s-d1893c434ca7.craft-spaces.bricks.cool/` reaches the Bricks static
  site host and returns the generated site.

## Acceptance Criteria

- Source-side TLS succeeds for `SNI=s-d1893c434ca7.craft-spaces.bricks.cool`.
- `https://s-d1893c434ca7.craft-spaces.bricks.cool/` returns HTTP 200.
- The response includes `X-Robots-Tag: noindex`.
- Dokku `bricks` domains include `craft.bricks.cool`,
  `craft-spaces.bricks.cool`, and `*.craft-spaces.bricks.cool`.

## Validation Commands

- `ssh -p 59322 root@149.28.225.252 dokku domains:report bricks`
- `ssh -p 59322 root@149.28.225.252 dokku certs:report bricks`
- `openssl s_client -connect 149.28.225.252:443 -servername s-d1893c434ca7.craft-spaces.bricks.cool -brief`
- `curl -I https://s-d1893c434ca7.craft-spaces.bricks.cool/`

## Result

- Added `craft-spaces.bricks.cool` and `*.craft-spaces.bricks.cool` to the
  production `bricks` Dokku app.
- Updated the production deploy workflow so future deployments preserve the
  wildcard site host instead of resetting domains back to only
  `craft.bricks.cool`.
- Verified `https://s-d1893c434ca7.craft-spaces.bricks.cool/` returns HTTP 200
  with `X-Robots-Tag: noindex`.
