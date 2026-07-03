# Dokku Preview GitHub Deployment Button

## Background

Vercel creates GitHub deployment timeline events on pull requests, which makes
GitHub show a native "View deployment" button. The Dokku preview workflow
currently deploys the preview app successfully but only exposes the result as an
Actions job, so the PR timeline does not get the same deployment affordance.

## Goals

- Publish a GitHub Deployment after a Dokku preview deploy succeeds.
- Attach the preview URL as the deployment `environment_url` so GitHub renders a
  "View deployment" button.
- Keep each PR preview environment transient and tied to the branch slug.

## Implementation Plan

1. Grant the Dokku preview workflow `deployments: write` permission.
2. After HTTPS enablement, create a GitHub Deployment for the pull request head
   SHA.
3. Create a successful Deployment Status with the Dokku preview URL and Actions
   run URL.
4. Update code maps so future deployment changes preserve the GitHub PR
   timeline integration.

## Acceptance Criteria

- When a Dokku PR preview deploy succeeds, the PR timeline shows a GitHub
  deployment event with a "View deployment" button.
- The button opens `https://<branch-slug>.craft-dev.bricks.cool`.
- The deployment is marked as a non-production transient environment.
- The workflow still cleans up Dokku preview apps on PR close.

## Validation Commands

- `npx js-yaml .github/workflows/dokku_preview_deploy.yml > /dev/null`
- `npx js-yaml docs/code_maps/feature_map.yaml > /dev/null`
- `npx js-yaml docs/code_maps/logic_map.yaml > /dev/null`
