# Fix Sandbox Runner Root Scoping

## Background

Preview apps originally mounted sandbox files under preview-specific host roots, but production and preview share the same database and channel IDs. Site workspace files should therefore resolve to the same persistent filesystem root in both environments. The runner also needs enough root scope information to mount the same host root that the app uses.

## Goals

- Let the app tell the runner which trusted sandbox root segments to use.
- Keep production and preview workspace files shared when they use the same database and channel IDs.
- Deploy the fix to Vultr and verify preview site tools can execute without runner root mismatch.

## Acceptance Criteria

- Production requests mount /home/bricks/data/production/sandboxes.
- Preview requests also mount /home/bricks/data/production/sandboxes.
- Runner container names include both root scope and user segment.
- Existing site tools no longer fail because git initialization runs against the wrong sandbox root.

## Validation

- `cd apps/node_sandbox_runner && npm run type-check`
- `cd apps/node_sandbox_runner && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/services/userSandboxService.test.ts src/services/channelSiteService.test.ts src/services/channelFileService.test.ts src/routes/channelSiteHost.test.ts src/services/localAgentLoopService.test.ts`
- `DOCS_URL=https://craft.bricks.cool npm run build` from `apps/docs_site`
- `ruby -e "require 'yaml'; YAML.load_file('docs/code_maps/feature_map.yaml'); YAML.load_file('docs/code_maps/logic_map.yaml'); puts 'code maps ok'"`
- `bash -n tools/sandbox_runner/install_vultr.sh`

## Deployment Evidence

- Vultr sandbox runner was redeployed with `SANDBOX_ROOT=/home/bricks/data`.
- Production and preview Dokku apps were configured with `BRICKS_SANDBOX_RUNNER_ROOT_SEGMENTS=production,sandboxes`.
- Current preview app mounts `/home/bricks/data/production/sandboxes:/app/data/sandboxes`.
- Existing preview workspace for the affected user/channel was copied into the shared production sandbox root without deleting the old preview copy.
- Runner verified `ac89e0e Initial Bricks site` in the shared workspace and listed the expected React/Vite starter files.
- Sandbox runner token was rotated and synced to production, preview, and GitHub `SANDBOX_RUNNER_TOKEN`.
