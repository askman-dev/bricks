# Node token copy OpenClaw commands

## Background

The Nodes settings screen can create node-scoped platform tokens for OpenClaw
plugin installations. Its current copy text is a human-readable summary with
Node, Plugin ID, Base URL, Scopes, and Token fields. Users still need to
manually translate that summary into OpenClaw CLI commands before configuring
the plugin.

OpenClaw 2026.4.15 supports targeted non-interactive configuration through
`openclaw config set`, which lets users configure only the Bricks channel
without running the broad `openclaw configure` flow.

## Goals

- Make the Nodes token copy action produce commands that can be pasted directly
  into a shell.
- Configure only `channels.dev-askman-bricks`.
- Preserve the generated token, plugin id, and base URL from the backend token
  bundle.
- Keep the copy flow simple and user-observable.

## Implementation Plan (phased)

### Phase 1: Command generation

- Replace the Nodes screen install summary with a shell command block.
- Use:
  - `openclaw config set channels.dev-askman-bricks.BRICKS_BASE_URL ...`
  - `openclaw config set channels.dev-askman-bricks.BRICKS_PLUGIN_ID ...`
  - `openclaw config set channels.dev-askman-bricks.BRICKS_PLATFORM_TOKEN ...`
  - `openclaw config validate`
  - `openclaw gateway restart`
  - `openclaw plugins inspect dev-askman-bricks`
- Quote shell values safely for pasted command execution.

### Phase 2: UI copy text

- Keep the generated command block visible after token generation.
- Change the copy button label and success message to reflect that commands are
  copied, not generic install information.

### Phase 3: Tests and validation

- Update the Nodes settings widget test so token generation shows OpenClaw
  commands.
- Add clipboard assertion that the copied text contains executable
  `openclaw config set` commands with the generated token bundle values.

Validation commands:

```bash
./tools/init_dev_env.sh
cd apps/mobile_chat_app
flutter test test/node_settings_screen_test.dart
flutter analyze
```

## Acceptance Criteria

- After generating a node token, the Nodes screen shows paste-ready OpenClaw
  commands.
- Copying the generated instructions writes those commands to the clipboard.
- The commands configure only `channels.dev-askman-bricks`.
- The copied commands include the generated base URL, plugin id, and platform
  token.
- The targeted widget test passes.
