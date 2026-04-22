---
name: openclaw-plugin-publish-prep
description: Prepare the Bricks OpenClaw plugin for external release on npm and ClawHub. Use when the user wants Codex to make apps/node_openclaw_plugin publishable, while leaving the final registry publish steps to a human operator.
---

Prepare `apps/node_openclaw_plugin` for public external distribution to OpenClaw users.

## Locked product decisions

Unless the user explicitly changes direction, treat these as already decided:

- Distribution target: **npm + ClawHub**
- Canonical plugin id stays **`dev-askman-bricks`**
- Final publish is **manual**:
  - Codex should prepare the package, docs, and validation steps
  - Codex should **not** run `npm publish` or `clawhub package publish` unless the user explicitly asks

If the current npm package name blocks public release, do **not** silently rename it. Surface the issue clearly and leave a concrete recommendation.

## When to use this skill

Use this skill when the user wants to:

- publish the Bricks OpenClaw plugin for external users
- make `apps/node_openclaw_plugin` installable via `openclaw plugins install <package>`
- prepare the plugin for both npm and ClawHub release
- generate a structured implementation prompt for Codex or another coding agent

## OpenClaw distribution facts

- External OpenClaw users install plugins with:
  ```bash
  openclaw plugins install <package>
  ```
- Bare package specs are resolved **ClawHub first, then npm fallback**.
- ClawHub is the canonical OpenClaw community discovery surface.
- Native plugins must ship `openclaw.plugin.json`.
- Packaged plugin releases should ship built JavaScript and point OpenClaw runtime metadata at built outputs, not source-only TypeScript paths.

## Required implementation scope

When preparing this plugin for release, Codex should cover all of the following unless the user narrows scope:

1. **Public package metadata**
   - remove `private: true`
   - add/verify `license`, `repository`, `homepage`, `bugs`
   - review `keywords`, publish files, and tarball inclusion behavior as needed

2. **OpenClaw packaged-release metadata**
   - verify the package still has correct native plugin metadata
   - add packaged-release metadata needed for ClawHub / packaged plugin installs
   - ensure runtime entrypoints reference built outputs
   - ensure compatibility/build metadata is present and accurate

3. **Artifact validation**
   - run:
     ```bash
     cd apps/node_openclaw_plugin
     npm test
     npm run type-check
     npm run build
     npm pack
     ```
   - inspect the resulting tarball and verify it contains:
     - `dist/*`
     - `openclaw.plugin.json`
     - package metadata needed by OpenClaw

4. **Release-facing docs**
   - document install/config/update steps for outside users
   - clearly distinguish local linked-install dev flow from public install flow

5. **Manual human handoff**
   - leave explicit publish commands for the human operator
   - include post-publish verification commands

## Explicit manual steps the human must run

Codex should mention these clearly in its final handoff, because the operator may forget them:

### Publish to npm

```bash
cd apps/node_openclaw_plugin
npm publish --access public
```

### Publish to ClawHub

Run a dry run first:

```bash
clawhub package publish <source> --dry-run
```

Then publish:

```bash
clawhub package publish <source>
```

### Verify the external-user flow

In a clean OpenClaw profile or clean machine:

```bash
openclaw plugins install <package-name>
openclaw plugins inspect dev-askman-bricks
openclaw configure
openclaw gateway restart
openclaw plugins update dev-askman-bricks
```

## PRD-style prompt

Use or adapt the following prompt when handing the task to Codex:

```text
Prepare `apps/node_openclaw_plugin` for public external release to OpenClaw users.

Product decisions already locked:
- Distribution target is npm + ClawHub
- Canonical plugin id must remain `dev-askman-bricks`
- Do not perform the final registry publish yourself; leave npm publish and ClawHub publish as explicit manual handoff steps for a human operator

Goal:
Make the plugin publishable and externally installable through the normal OpenClaw plugin flow, so a user can eventually run `openclaw plugins install <package-name>` without cloning this repository.

Scope:
1. Update `apps/node_openclaw_plugin/package.json` so it is publicly publishable:
   - remove `private: true`
   - add/verify release metadata such as `license`, `repository`, `homepage`, and `bugs`
   - review whether additional package inclusion rules are needed so the published tarball is correct
2. Add or correct packaged OpenClaw plugin metadata required for public distribution:
   - keep native plugin behavior working
   - ensure built runtime entrypoints are used for packaged installs
   - add any compatibility/build metadata expected by ClawHub or packaged OpenClaw plugin installs
3. Update release-facing documentation for external users:
   - public install flow
   - config/onboarding flow
   - update flow
   - troubleshooting notes if needed
4. Validate the artifact end to end:
   - `cd apps/node_openclaw_plugin && npm test`
   - `cd apps/node_openclaw_plugin && npm run type-check`
   - `cd apps/node_openclaw_plugin && npm run build`
   - `cd apps/node_openclaw_plugin && npm pack`
   - inspect the packed tarball and verify that the built runtime files and manifest are present

Constraints:
- Do not rename the plugin id away from `dev-askman-bricks`
- Do not silently rename the npm package unless absolutely required; if the current package name is unsuitable for public publishing, explain the issue clearly and recommend the smallest safe rename
- Do not run `npm publish` or `clawhub package publish`
- Do not make unrelated changes outside the release-prep scope

Deliverables:
- code and documentation changes needed for release prep
- a concise summary of what changed
- exact manual commands the human must run next for:
  - npm publish
  - ClawHub dry run and publish
  - clean-install verification
```

## Response pattern

When using this skill:

- restate the locked decisions briefly
- keep the work focused on release preparation, not registry-side publication
- always end with a human handoff checklist for publish + verification
