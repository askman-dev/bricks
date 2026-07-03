# Channel React Site Workspace and Preview

## Background

Bricks needs a channel-scoped website workspace so a user can ask the AI agent to create a static React site, build it, and publish the latest successful build to a fixed public URL. The chat UI remains the control surface, but the website work itself is handled through agent tool calls and filesystem operations rather than a fixed chat flow.

Each channel has one project. Threads share the parent channel workspace and conversation context, but the generated site, git repository, build output, and public URL are channel-level resources. The first supported site type is a static Vite + React + TypeScript app with an intentionally thin starter template.

User isolation is the security boundary. Agents may operate inside the current user's mounted workspace root. The current channel workspace is writable. Other channels owned by the same user are invisible by default and become available only when the agent explicitly discovers or requests them through atomic tools. Other users' workspaces, media, build outputs, and logs must remain inaccessible even if a prompt mentions them.

Current media upload already uses `user_id` in the database and API authorization paths. However, the low-level channel filesystem service currently derives directories from `channelId` alone. This feature must move filesystem layout and path resolution to a user-scoped directory model so user-level isolation also exists at the file path layer.

The public site URL is a loose binding, not a derived identity. A channel has a database-backed public slug such as:

```text
https://abc-ddd222.craft-spaces.bricks.cool
```

The slug must not expose the raw user ID or channel ID. The structure should support changing or resetting the slug later, but this task does not add a reset UI.

## Goals

- Create one independent React/Vite/TypeScript website workspace per channel.
- Initialize each channel workspace as an independent git repository with a safe starter commit.
- Let agent tools operate on the current channel workspace and run npm/git/build commands.
- Keep other users' files inaccessible at both API and filesystem path layers.
- Let the agent discover same-user channels and request read-only workspace access through atomic tools, without hardcoded prompt syntax.
- Store the channel public slug in the database and serve each channel at a fixed `craft-spaces.bricks.cool` subdomain.
- Keep the public site on the latest successful build when later builds fail.
- Preserve only the latest build output and latest build logs/status, not a build history tree.
- Copy referenced channel media into the site's `public/` directory when the agent wants the site to use uploaded or generated assets.
- Prevent indexing of `*.craft-spaces.bricks.cool`.

## Implementation Plan

1. Define the user-scoped filesystem layout.
   - Change channel file path services so every channel directory is nested under a user-scoped root.
   - Use stable, sanitized path segments that do not reveal raw user IDs or raw channel IDs.
   - Keep the active channel workspace writable and same-user referenced workspaces read-only at tool/runtime boundaries.
   - Preserve path traversal protections for absolute paths, `..`, empty segments, null bytes, and malformed separators.
   - Update existing media path resolution so uploaded and generated media moves under the user-scoped layout.

2. Add channel site metadata.
   - Add a database table or extension that binds `user_id`, `channel_id`, `public_slug`, and site metadata.
   - Enforce uniqueness on `public_slug`.
   - Generate opaque slugs suitable for DNS labels under `craft-spaces.bricks.cool`.
   - Keep the database as the source of truth for public URL binding.
   - Add a workspace configuration tool that returns the current channel's public URL, workspace paths, latest build log path, latest build status path, current dist path, and future GitHub sync remote.

3. Initialize channel workspaces.
   - Add a service that ensures a channel workspace exists before agent file operations.
   - Create a thin Vite + React + TypeScript starter project with `package.json`, `package-lock.json`, `src/`, `public/robots.txt`, and base CSS.
   - Run `git init` for the workspace and create the initial commit.
   - Keep runtime/build artifacts out of git through `.gitignore`.
   - Do not install extra UI, routing, or state libraries in the starter template.

4. Add atomic workspace tools for the agent.
   - Provide file tools for the current writable workspace: list, read, write, mkdir, delete, and shell execution within the workspace.
   - Provide discovery tools that can list/search the user's channels and resolve a referenced same-user channel to a read-only workspace root.
   - Provide a config tool for public URL and build/debug paths.
   - Provide media copy tools that copy selected uploaded/generated media into the current site's `public/assets/` directory.
   - Ensure tools return structured paths and errors so the agent can compose operations without relying on hidden prompt formats.

5. Implement the build skill/tool.
   - Let the agent decide when to call build.
   - Run npm commands in the current channel workspace.
   - Support arbitrary npm dependencies and scripts, accepting the user-level risk for code inside the current user's mount.
   - Keep each channel's `node_modules`, lockfile, npm cache, and build outputs separate.
   - Write the latest build log to `jobs/build.log`.
   - Write the latest build status to `jobs/build.json`.
   - Build into a temporary dist directory, then atomically replace `web/dist/` only on success.
   - On failure, keep the existing `web/dist/` unchanged and make logs readable by agent tools.

6. Serve public static sites.
   - Add a static host route that resolves `Host` to `public_slug`, then to the channel's latest successful `web/dist/`.
   - Support React SPA fallback by serving `index.html` for non-file paths.
   - Serve static assets with safe content types and cache headers.
   - Add `X-Robots-Tag: noindex` for all `craft-spaces.bricks.cool` responses.
   - Also include `public/robots.txt` in the template to discourage indexing.

7. Update docs, tests, and code maps.
   - Add backend tests for slug uniqueness, host resolution, user-scoped path resolution, workspace initialization, build success/failure behavior, and same-user read-only reference rules.
   - Add route tests for static host fallback, missing slug, stale failed build behavior, and `noindex` headers.
   - Add local agent tool tests for workspace config, file writes, media copy, and build log reads.
   - Update `docs/code_maps/feature_map.yaml` and `docs/code_maps/logic_map.yaml` after implementation because this adds feature entry points, filesystem logic, build logic, public host routing, and tests.

## Acceptance Criteria

- A new channel can be initialized with exactly one React/Vite/TypeScript website workspace.
- The channel workspace is an independent git repository with an initial commit.
- The agent can write source files in the current channel workspace and run npm commands there.
- A successful build produces a static React site under the channel's latest `web/dist/`.
- A fixed public URL under `craft-spaces.bricks.cool` serves the latest successful build.
- React SPA routes under the public URL fall back to `index.html`.
- A failed build writes readable `jobs/build.log` and `jobs/build.json` and does not replace the latest successful public site.
- Other users' workspaces and media cannot be resolved through file paths, media IDs, public slug metadata, or workspace tools.
- Same-user other channels are not exposed to the agent unless discovered or requested through explicit tools.
- Referenced same-user workspaces are read-only unless they are the active channel.
- Uploaded or generated media can be copied into the current site's `public/assets/` directory for use by the React app.
- `*.craft-spaces.bricks.cool` responses include `X-Robots-Tag: noindex`.
- No build history directories remain after normal operation; only the latest dist, latest build log, and latest build status are retained.
- Code maps are updated to include the new workspace, build, public host, and static React site surfaces.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test`
- `cd packages/project_system && dart test`

## Implementation Notes

- First implementation slice adds the backend/tool/public-host loop:
  - user-scoped opaque channel filesystem paths
  - `channel_sites` public slug binding
  - React/Vite/TypeScript starter workspace initialization
  - agent tools for workspace config, file operations, shell execution, build,
    and media copy
  - host-based static serving for `<slug>.craft-spaces.bricks.cool`
- Explicit mobile UI affordances and same-user cross-channel read-only discovery
  can be layered on top of the tool API in a follow-up slice.
