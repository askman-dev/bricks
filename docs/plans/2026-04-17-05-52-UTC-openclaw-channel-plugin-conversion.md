# Background
`apps/node_openclaw_plugin` currently exposes OpenClaw package metadata and onboarding prompts, but OpenClaw still treats it like a generic plugin instead of a true channel plugin. That leaves `channels.dev-askman-bricks.*` invalid in `openclaw config set`, which blocks narrow channel-only configuration and makes the metadata/runtime contract inconsistent.

# Goals
- Make `dev-askman-bricks` a real OpenClaw channel from manifest, package metadata, and runtime registration perspectives.
- Keep the existing Bricks pull-only standalone runner intact.
- Restore the intended config surface so `channels.dev-askman-bricks.*` is valid.
- Update targeted docs/tests so the new channel contract is explicit and regression-resistant.

# Implementation Plan (phased)
## Phase 1: Channel contract alignment
1. Update `apps/node_openclaw_plugin/openclaw.plugin.json` to declare channel ownership (`kind`, `channels`) while preserving `channelConfigs`.
2. Add/adjust package metadata (`openclaw.setupEntry` if needed) so setup/configure surfaces can load the plugin as a channel.

## Phase 2: Minimal native channel runtime
1. Replace the current onboarding-only extension entry with a real channel entry that calls `api.registerChannel({ plugin })`.
2. Define the smallest viable channel plugin object: metadata, config schema, and setup/config wiring for `channels.dev-askman-bricks`.
3. Add a lightweight setup-only entry for setup/configure flows.

## Phase 3: Verification and docs
1. Update `apps/node_openclaw_plugin/README.md` to document the channel config path and command flow.
2. Update tests to cover channel registration/config wiring instead of the old onboarding-only object shape.
3. Run package build/tests and local OpenClaw verification, including `openclaw config set channels.dev-askman-bricks.*`.

# Acceptance Criteria
- OpenClaw accepts `channels.dev-askman-bricks.*` writes for the Bricks plugin.
- `openclaw plugins inspect dev-askman-bricks` shows the plugin as a channel-capability plugin rather than a generic non-capability plugin.
- `apps/node_openclaw_plugin` build/test/type-check continue to pass.
- The README explains how to configure Bricks via the channel config path.
