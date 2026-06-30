# gVisor Sandbox Runner

## Background

Implement the safe per-user local filesystem and shell execution design for Bricks. The main Bricks app should remain the control plane and should not execute user-authored code directly. A same-host sandbox runner should lazily create/start one gVisor-backed container per user and mount only that user's persistent filesystem.

## Goals

- Add a standalone Node sandbox runner service.
- Run user commands in per-user gVisor containers with only that user's filesystem mounted.
- Configure Bricks production/preview deployments to call the sandbox runner over HTTP.
- Keep the current Bricks application deployment model intact.
- Document Vultr host setup for runsc/Docker/systemd.

## Implementation Plan

1. Add `apps/node_sandbox_runner` with `/healthz` and `/v1/run`.
2. Harden Bricks API runner selection so production rejects local execution.
3. Update Dockerfile, Dokku workflows, and docs to use `BRICKS_SANDBOX_RUNNER=http`.
4. Add deployment/setup script for the Vultr host sandbox runner.
5. Run focused Node tests/type checks and YAML validation.

## Acceptance Criteria

- Bricks API no longer defaults to local sandbox execution in production.
- The sandbox runner validates user segment and cwd, creates per-user filesystem roots, and uses Docker `--runtime=runsc`.
- Stopped per-user containers are restarted before command execution.
- Deployment config uses `/app/data/sandboxes` and HTTP runner env vars.
- The repository records validation commands and code map updates.

## Validation

- `bash -n tools/sandbox_runner/install_vultr.sh`
- `cd apps/node_sandbox_runner && npm run type-check`
- `cd apps/node_sandbox_runner && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/services/userSandboxService.test.ts src/services/channelFileService.test.ts src/services/channelSiteService.test.ts src/routes/channelSiteHost.test.ts src/services/localAgentLoopService.test.ts`
- `ruby -e "require 'yaml'; YAML.load_file('docs/code_maps/feature_map.yaml'); YAML.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps ok'"`

## Deployment Evidence

- Vultr host `149.28.225.252` has `runsc` registered as a Docker runtime.
- `bricks-sandbox-runner` is enabled as a systemd service on `172.17.0.1:8787`.
- Dokku app `bricks` is configured with `BRICKS_SANDBOX_RUNNER=http`, `BRICKS_SANDBOX_RUNNER_URL=http://172.17.0.1:8787`, and `/home/bricks/data/production/sandboxes:/app/data/sandboxes`.
- UFW allows only Docker bridge traffic from `172.17.0.0/16` to `172.17.0.1:8787` for the runner; the runner port is not opened publicly.
- A token-authenticated `/v1/run` request created a file inside a temporary per-user gVisor container under the production sandbox root, and the temporary verification container/directory was removed afterward.
