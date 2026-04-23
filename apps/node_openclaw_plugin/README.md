# @askman-dev/bricks-openclaw-plugin

`@askman-dev/bricks-openclaw-plugin` is the Bricks channel plugin for OpenClaw.

- **Canonical channel/plugin id**: `dev-askman-bricks` (must stay unchanged)
- **Distribution target**: npm + ClawHub
- **Runtime mode**: pull-only Bricks event runner managed by OpenClaw gateway

## Public install flow (external users)

Install from package registry (OpenClaw resolves ClawHub first, then npm):

```bash
openclaw plugins install @askman-dev/bricks-openclaw-plugin
openclaw gateway restart
```

Inspect the installed plugin metadata:

```bash
openclaw plugins inspect dev-askman-bricks
```

> Development-only local install is still supported, but external users should
> prefer package install instead of cloning this repository.

## Configure / onboarding flow

After install, run one of:

```bash
openclaw onboard
# or
openclaw configure
```

Choose `dev-askman-bricks` (Bricks), then provide:

- `BRICKS_BASE_URL`
- `BRICKS_PLUGIN_ID` (normally `dev-askman-bricks`)
- `BRICKS_PLATFORM_TOKEN`

Equivalent direct config commands:

```bash
openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL https://your-bricks-api.example.com
openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID dev-askman-bricks
openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN 'your-jwt-token'
openclaw config validate
openclaw gateway restart
```

## Update flow

Update an existing installation:

```bash
openclaw plugins update dev-askman-bricks
openclaw gateway restart
```

If you changed channel credentials or endpoint, re-run `openclaw configure` (or
`openclaw config set ...`) and then restart gateway.

## ClawHub packaging metadata

ClawHub publish validation requires OpenClaw package metadata in
`package.json` under the `openclaw.compat` and `openclaw.build` keys. This
package now declares:

- `openclaw.compat.pluginApi`
- `openclaw.compat.minGatewayVersion`
- `openclaw.build.openclawVersion`
- `openclaw.build.pluginSdkVersion`

If you rebuild a release archive after changing package metadata, regenerate the
package artifact from the current plugin directory so the updated `package.json`
is included.

## Runtime behavior summary

When OpenClaw gateway starts/restarts, the plugin runner is host-managed:

1. Starts on gateway account lifecycle (`startAccount`)
2. Polls `GET /api/v1/platform/events`
3. ACKs events via `POST /api/v1/platform/events/ack`
4. Hands user messages to OpenClaw inbound/session pipeline
5. Writes assistant output via `POST/PATCH /api/v1/platform/messages`
6. Stops gracefully on gateway shutdown via `AbortSignal`

## Troubleshooting

### Plugin installed but channel not responding

- Verify config exists under `channels.dev-askman-bricks`.
- Validate config and restart gateway:

```bash
openclaw config validate
openclaw gateway restart
```

### Auth / token errors

The plugin validates platform token claims at startup (`typ=platform_plugin`,
matching `pluginId`, and required `userId`). Regenerate token if claims are
invalid.

### Packaging caveat

`openclaw plugins install` uses `npm install --ignore-scripts`. Do not rely on
npm `postinstall` to write configuration; always configure via OpenClaw
onboarding/config commands.

## Development-only local flow

Use local path or linked install only while developing this repository:

```bash
openclaw plugins install ./apps/node_openclaw_plugin
# or
openclaw plugins install -l ./apps/node_openclaw_plugin
openclaw gateway restart
```

Standalone runner debug (outside gateway lifecycle):

```bash
cd apps/node_openclaw_plugin
npm install
npm run build
npm start
```

## Optional runtime environment variables

| Variable | Required | Description |
|---|---|---|
| `OPENCLAW_PLUGIN_POLL_INTERVAL_MS` | No | Poll interval in ms (default `2000`) |
| `OPENCLAW_PLUGIN_DEFAULT_CURSOR` | No | Initial cursor (default `cur_0`) |
| `OPENCLAW_PLUGIN_STATE_FILE` | No | Local state file path (default `~/.bricks/node_openclaw_plugin_state.json`) |
| `OPENCLAW_PLUGIN_ASSISTANT_NAME` | No | Assistant name in output messages (default `Node OpenClaw Plugin`) |
