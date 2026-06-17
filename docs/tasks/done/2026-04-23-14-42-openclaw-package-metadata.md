# Background

The OpenClaw plugin package at `apps/node_openclaw_plugin/package.json` is missing ClawHub publish metadata under the `openclaw` field. ClawHub rejects the package upload when `openclaw.compat.pluginApi` and `openclaw.build.openclawVersion` are absent.

# Goals

1. Add the required OpenClaw publish metadata to the plugin package.
2. Align the metadata with the plugin's current OpenClaw dependency version.
3. Keep the package ready for external ClawHub publishing without changing runtime behavior.

# Implementation Plan

## Phase 1

Inspect the existing plugin package metadata and confirm the ClawHub-required `openclaw.compat` and `openclaw.build` fields from the OpenClaw docs.

## Phase 2

Update `apps/node_openclaw_plugin/package.json` to add the missing compatibility and build metadata using the current OpenClaw package version as the baseline.

## Phase 3

Run the existing plugin validation commands to ensure the package still builds and its tests continue to pass after the metadata-only change.

# Acceptance Criteria

1. `apps/node_openclaw_plugin/package.json` includes `openclaw.compat.pluginApi`.
2. `apps/node_openclaw_plugin/package.json` includes `openclaw.compat.minGatewayVersion`.
3. `apps/node_openclaw_plugin/package.json` includes `openclaw.build.openclawVersion`.
4. `apps/node_openclaw_plugin/package.json` includes `openclaw.build.pluginSdkVersion`.
5. The plugin's existing test, type-check, and build commands still complete successfully.
