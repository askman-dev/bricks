# Dokku Channel Media Deployment Plan

## Background

Bricks is moving away from Vercel for the production deployment because upcoming workspace and media features need durable local filesystem access. The product model is one Bricks instance with many channels. Each channel binds to a workspace, and AI coding agents need ordinary filesystem access to the channel workspace and media files.

The existing Gemini media architecture plan correctly identifies the need for image input, generated media persistence, preview/download APIs, and durable async jobs. It should be adjusted for this deployment: media must not be treated as a global storage root. Uploaded media, generated images, generated videos, thumbnails, website source, and build output should live inside the same channel-scoped directory so ownership and agent scope are easy to reason about.

Production will run on a Vultr server with Dokku. The database remains Turso and is not part of this migration. GitHub OAuth has been configured with a fixed callback URL:

```text
https://craft.bricks.cool/api/callback
```

Preview deployments must use branch-scoped subdomains under:

```text
https://<branch-slug>.craft-dev.bricks.cool
```

Cloudflare already points `*.craft-dev.bricks.cool` to the Vultr server IP. GitHub can only callback to the production host, so preview login must continue to use the existing cross-origin OAuth state flow: preview initiates login with `return_to`, production callback consumes the server-side OAuth state, then redirects back to the preview host with the token fragment.

## Goals

- Deploy a production Bricks instance to Dokku at `https://craft.bricks.cool`.
- Keep Turso as the database backend and migrate Vercel environment variables into Dokku config.
- Add GitHub Actions deployment automation for main branch production deploys.
- Add GitHub Actions preview automation for PR open/update, deploying each branch to `https://<branch-slug>.craft-dev.bricks.cool`.
- Ensure each preview app has an isolated host data root and cannot share production or other preview channel files.
- Extend OAuth return URL validation to allow `https://<branch-slug>.craft-dev.bricks.cool` while preserving the fixed production callback.
- Implement the first media milestone: image upload as chat input, image preview/download, and generated image persistence.
- Store all channel media and generated website files under the channel directory so AI coding agents can access them.
- Update code maps after implementation because this touches feature entry points, backend logic, deployment flow, OAuth rules, storage layout, and tests.

## Implementation Plan

1. Define the channel-scoped filesystem contract.
   - Add a backend configuration value such as `BRICKS_CHANNEL_ROOT`, defaulting to a safe local development path and set to `/app/data/channels` in Dokku.
   - Use a stable channel root layout:

     ```text
     /app/data/channels/
       <channel-id>/
         workspace/
         media/
           uploads/
           generated/
             images/
           thumbnails/
         web/
           dist/
         jobs/
         .bricks/
     ```

   - Store only channel-relative paths in the database, never absolute host paths.
   - Add path normalization guards so media paths cannot escape the channel root through `..`, absolute paths, symlinks, or malformed separators.
   - Keep the first agent read/write policy simple: agents may operate within the current channel root; stricter sandboxing can follow after the architecture is working.

2. Adjust the existing media plan for channel-local storage.
   - Treat the existing `docs/tasks/doing/2026-06-29-14-32-CST-gemini-image-video-generation-architecture.md` as the functional media baseline.
   - Amend or supersede its storage assumption so "Bricks-owned storage" means channel-scoped filesystem storage for this deployment phase.
   - Limit this first implementation to image upload as chat input, image preview/download, and generated image persistence.
   - Leave durable video generation as a later milestone, but keep schema/API choices compatible with future generated videos.

3. Implement media schema and backend file services.
   - Add database tables for media assets, message attachment joins, and generated media job/result metadata if required by the image generation flow.
   - Include `user_id`, `channel_id`, optional `thread_id`, media kind, origin, MIME type, size, dimensions, status, and channel-relative file paths.
   - Add backend services to create channel directories, write uploaded files, write generated image outputs, create thumbnails where feasible, and resolve authorized preview/download paths.
   - Enforce MIME allowlists, size limits, ownership checks, and channel scope checks.

4. Add media APIs.
   - Add authenticated upload endpoints for image attachments.
   - Add preview and download/content endpoints that authorize by user and channel before reading from disk.
   - Add generated-image persistence through either a direct image generation endpoint or the existing chat/tool flow, saving provider output into `media/generated/images/`.
   - Return media metadata needed by Flutter: ID, kind, origin, thumbnail URL, content URL, download URL, status, MIME type, dimensions, and error text.

5. Extend chat transport and Flutter UI for image attachments.
   - Extend chat message DTOs, sync/SSE serialization, and local mobile models to include attachments.
   - Add composer image selection and upload-before-send behavior.
   - Render uploaded and generated image attachments in chat messages with preview/open/download affordances.
   - Allow empty text only when image attachments are present if this product behavior is desired for the first milestone.

6. Add provider integration for generated images.
   - Add or extend Gemini capability detection for image generation.
   - Persist generated image bytes immediately into the channel directory.
   - Attach generated images to assistant messages and synchronize them through existing chat update paths.
   - Represent provider errors and safety blocks as explicit failed media/message states, not permanent spinners.

7. Prepare Dokku production deployment.
   - Install and configure Dokku on the Vultr host.
   - Create a production app, for example `bricks`.
   - Mount host data:

     ```text
     /home/bricks/data/production/channels -> /app/data/channels
     ```

   - Configure the production domain `craft.bricks.cool`.
   - Enable HTTPS.
   - Set Dokku config values migrated from Vercel, including Turso, GitHub OAuth, JWT/encryption, CORS, cron, provider keys, and `BRICKS_CHANNEL_ROOT=/app/data/channels`.
   - Ensure the app runs as at least a web process and a worker process if generated image work or future media jobs require background processing.

8. Add GitHub Actions production deployment.
   - Replace or supersede the current Vercel deploy workflow with a Dokku deploy workflow for main branch pushes.
   - Use repository secrets for SSH key, host, port `59322`, app name, and deployment user.
   - Run the repository bootstrap/build commands before deploy where appropriate, or let Dokku run the build from the pushed source.
   - Keep deployment concurrency so only one production deployment runs at a time.

9. Add GitHub Actions preview deployment.
   - On PR open/synchronize/reopen, compute a safe branch slug from the source branch:
     - lowercase
     - replace `/` and invalid DNS characters with `-`
     - collapse repeated `-`
     - append a short hash when truncation or collision protection is needed
   - Create or update a Dokku app for the preview, for example `bricks-preview-<branch-slug>`.
   - Mount an isolated host data root:

     ```text
     /home/bricks/data/previews/<branch-slug>/channels -> /app/data/channels
     ```

   - Set the preview domain:

     ```text
     <branch-slug>.craft-dev.bricks.cool
     ```

   - Set preview config values. Keep `GITHUB_CALLBACK_URL=https://craft.bricks.cool/api/callback` so GitHub always returns to production, and set return-origin allow rules for the preview domain.
   - Deploy the PR branch to the preview app.
   - On PR close/merge, destroy the preview Dokku app and remove `/home/bricks/data/previews/<branch-slug>` after verifying the slug belongs to the PR workflow namespace.

10. Update OAuth domain rules.
    - Extend `isAllowedReturnTo` to allow HTTPS origins matching:

      ```text
      <branch-slug>.craft-dev.bricks.cool
      ```

    - Keep `craft.bricks.cool` allowed through the callback origin.
    - Keep native app callback support.
    - Keep localhost allowed only outside production.
    - Add unit tests for valid and invalid preview return targets, including branch slugs with hyphenated names and rejection of sibling or attacker-controlled domains.
    - Validate that preview login redirects back to the preview host using the existing token fragment delivery.

11. Add operational runbooks and environment migration notes.
    - Document the Dokku app setup commands, storage mounts, domains, GitHub Actions secrets, and rollback steps.
    - Document how to export Vercel env values and set them in Dokku without committing secrets.
    - Document the production and preview data roots and cleanup rules.
    - Document that preview apps do not share production channel disk and are removed after PR close/merge.

12. Update code maps and task lifecycle.
    - Update `docs/code_maps/feature_map.yaml` for media attachments, channel-local storage, Dokku deployment, and OAuth preview domains.
    - Update `docs/code_maps/logic_map.yaml` for media path resolution, OAuth validation, deployment workflows, and preview cleanup risks.
    - Move this task through the lifecycle folders as implementation starts and completes.

## Acceptance Criteria

- Production Bricks is reachable at `https://craft.bricks.cool`.
- The production Dokku app uses `/app/data/channels` inside the container and persists data under `/home/bricks/data/production/channels` on the host.
- A main branch push automatically builds and deploys the production Dokku app.
- Opening or updating a PR deploys a preview app at `https://<branch-slug>.craft-dev.bricks.cool`.
- Each preview app uses a unique data root under `/home/bricks/data/previews/<branch-slug>/channels`.
- Preview apps cannot read or write production channel files or another preview app's channel files through the configured mount.
- Closing or merging a PR destroys the matching preview app and removes its preview data root.
- GitHub OAuth login works from `https://craft.bricks.cool`.
- GitHub OAuth login from a preview domain returns the user to that preview domain after the fixed production callback at `https://craft.bricks.cool/api/callback`.
- Invalid OAuth `return_to` origins are rejected.
- A user can upload an image in chat, send it with text, refresh, and still see the image attachment.
- A user can open/download an uploaded image through authenticated media routes.
- A generated image is saved under the current channel directory and rendered as a durable assistant attachment.
- Media database rows store channel-relative paths rather than absolute host paths.
- Existing text-only chat, OpenClaw routing, sync/SSE, and thread naming continue to work.
- Code maps reflect the new media, OAuth, deployment, and channel filesystem paths.

## Validation Commands

- `./tools/init_dev_env.sh`
- `cd apps/node_backend && npm test`
- `cd apps/node_backend && npm run type-check`
- `cd apps/mobile_chat_app && flutter test`
- `cd packages/bricks_ai_smoke_test && dart test`
- `ssh -p 59322 root@149.28.225.252 dokku apps:list`
- `ssh -p 59322 root@149.28.225.252 dokku config:show bricks`
- `curl -I https://craft.bricks.cool`
- `curl -I https://<branch-slug>.craft-dev.bricks.cool`
