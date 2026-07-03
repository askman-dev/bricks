# Site Publish Status

## Background

Channel site workspaces can require a build/publish step before the public URL reflects the latest code. Users should not need to know when to ask for compilation, and the product needs a visible site status surface before deeper automation is added.

## Goals

- Add a lightweight site status indicator to the chat title bar.
- Show publish details on click: public URL, latest publish time, current commit, and live published commit.
- Use git commit IDs as the first architecture-level source of truth.
- Keep dirty workspace detection out of this first version.
- Let users trigger publish through a simple prompt while AI tools can call the structured publish pipeline.

## Implementation

- Added `channel_sites.latest_publish_commit_sha` and `channel_sites.published_commit_sha`.
- Updated site publish/build to create a git snapshot commit before building, record the attempted commit, and only advance the published commit on successful builds.
- Added `site_publish_status` agent tool and strengthened `site_build` guidance so agents publish after editing site files.
- Added authenticated `/api/sites/:channelId/publish-status` for the UI.
- Added a Flutter title-bar Site status button with a publish details dialog and a Publish prompt action.
- Updated code maps for the new feature entry points and regression risks.

## Validation Commands

- `cd apps/node_backend && npm run type-check`
- `cd apps/node_backend && npm test -- --run src/routes/channelSiteApi.test.ts src/routes/channelSiteHost.test.ts src/services/channelSiteService.test.ts src/services/userSandboxService.test.ts`
- `cd apps/mobile_chat_app && flutter analyze`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null && npx js-yaml docs/code_maps/logic_map.yaml > /dev/null`
