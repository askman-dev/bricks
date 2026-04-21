---
name: openclaw-plugin-refresh
description: Rebuild, reinstall, and restart the local Bricks OpenClaw plugin after pulling repository updates. Use when the user wants their local OpenClaw install to pick up new code from apps/node_openclaw_plugin.
---

Reapply the locally checked out Bricks OpenClaw plugin to a local OpenClaw installation.

## When to use this skill

Use this skill when the user:

- pulled or merged new repository changes and wants OpenClaw to use the updated plugin code
- asks how to apply local changes under `apps/node_openclaw_plugin`
- needs the safest repo-specific rebuild + reinstall + restart workflow
- wants to know whether a rebuild alone is enough or a plugin reinstall is needed

## Repository-specific facts

- The plugin package lives at `apps/node_openclaw_plugin`.
- OpenClaw loads the built extension from `dist/openclawExtension.js`, so source-only edits do not apply until the package is rebuilt.
- The package declares `engines.node >=22.14.0`.
- This repository recommends linked local install for development:
  ```bash
  openclaw plugins install -l ./apps/node_openclaw_plugin
  ```
- In the normal flow, the Bricks runner is managed by `openclaw gateway`; do not rely on manual `npm start` unless explicitly doing standalone runner debugging.

## Default workflow (safe path)

From the repository root:

```bash
cd apps/node_openclaw_plugin
npm install
npm run build

cd ../..
openclaw plugins install -l ./apps/node_openclaw_plugin
openclaw gateway restart
```

Use this path when:

- you are not sure whether the plugin was previously installed with `-l`
- plugin metadata may have changed
- you want the least surprising workflow after updating `main`

## Fast path

If the plugin was already installed with `-l ./apps/node_openclaw_plugin` and only code changed:

```bash
cd apps/node_openclaw_plugin
npm run build

cd ../..
openclaw gateway restart
```

Use this only when you are confident the existing install is already linked to the repo checkout.

## Config update path

If the Bricks connection settings changed, refresh the stored channel config before restarting:

```bash
openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL https://your-bricks-api.example.com
openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID dev-askman-bricks
openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN 'your-jwt-token'
openclaw config validate
openclaw gateway restart
```

If the user prefers the interactive flow:

```bash
openclaw onboard
# or
openclaw configure
```

## Verification

After restart, inspect gateway logs:

```bash
tail -f ~/.openclaw/logs/gateway.log
```

Expected signals include lines such as:

- `starting Bricks pull runner`
- `[node_openclaw_plugin] started with cursor: ...`

If needed, also inspect:

```bash
tail -f ~/.openclaw/logs/gateway.err.log
```

## Troubleshooting

- If the new code is not taking effect, rebuild first; OpenClaw reads `dist/*`, not `src/*`.
- If behavior still looks stale, rerun:
  ```bash
  openclaw plugins install -l ./apps/node_openclaw_plugin
  openclaw gateway restart
  ```
- If the gateway reports invalid or missing `BRICKS_*` values, refresh `channels.dev-askman-bricks.*` via `openclaw config set` or rerun `openclaw configure`.
- If startup fails on Node version, upgrade Node to `>=22.14.0`.
- If logs show transient `fetch failed` / `ENOTFOUND`, treat that as connectivity or DNS trouble against the configured Bricks base URL and check the current gateway logs for recovery/backoff behavior.

## Response pattern

When using this skill, tailor the answer to the user's install state:

- prefer the fast path only if linked install is already confirmed
- otherwise recommend the safe path
- mention config refresh only if credentials or base URL changed
- include a short verification step so the user knows the new plugin code is actually running
