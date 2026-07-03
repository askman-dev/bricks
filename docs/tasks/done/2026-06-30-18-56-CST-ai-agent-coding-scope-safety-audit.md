# AI Agent Coding Scope Safety Audit

## Background

Research the current AI, agent, and coding-related code paths and identify how Bricks can avoid cross-user file mutations and prevent the host machine from being formatted or otherwise modified outside the intended channel workspace.

## Findings

- The active coding surface is the channel React site workspace tool family exposed through the chat agent loop.
- User and channel filesystem roots are derived from opaque hashed segments under `BRICKS_SANDBOX_ROOT`.
- Workspace file read, write, mkdir, delete, build, and media copy tools consistently receive the authenticated `userId` from the server-side tool closure.
- Workspace paths are normalized as channel-relative paths and reject absolute paths, `..`, `.`, empty segments, and NUL bytes.
- The largest remaining risk is `site.shell.exec`, which accepts an arbitrary shell command and only constrains `cwd` to the channel workspace. That does not prevent commands from reading or writing host paths outside the workspace.
- Broad repository formatting commands still exist in developer scripts, so an AI-facing coding layer should not expose generic `dart format .`, `melos format`, or raw shell execution.

## Recommendations

- Replace generic `site.shell.exec` with a narrow command runner allowlist, for example `npm_install`, `npm_run_build`, `git_status`, and scoped formatter commands.
- Bind site tools to the current request channel by default and reject model-supplied `channelId` that differs from the current chat channel unless an explicit server-side delegation flow allows it.
- Run builds and any formatter inside a process/container/jail whose filesystem mount is only the channel workspace plus disposable package caches.
- Forbid absolute paths and parent traversal at the command layer, not only at the file API layer.
- Format only files returned by the same scoped file API or changed-file registry; never expose repo-root formatting commands to the model.
- Keep generated media and site assets channel-scoped, and continue checking media ownership before copying into a site workspace.

## Validation

- Read-only code inspection only.
- No Flutter/Dart checks, formatters, builds, production services, or broad shell commands were run.
- Code maps were inspected but not updated because this audit did not change functional entry paths, business logic, tests, or documentation index structure.
