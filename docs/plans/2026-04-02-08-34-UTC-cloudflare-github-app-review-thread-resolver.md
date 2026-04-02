# Plan: Cloudflare GitHub App review-thread resolver

## Problem

GitHub Actions workflow runs triggered by `copilot-swe-agent[bot]` remain gated by Copilot workflow approval, so repository-native automation cannot reliably resolve outdated review threads after Copilot finishes a PR iteration.

## Approach

Move the resolver outside GitHub Actions and into a GitHub App webhook hosted on Cloudflare Workers. The worker will:

1. Receive `issue_comment` webhooks directly from GitHub
2. Verify the webhook signature
3. Filter only PR comments created by `copilot-swe-agent[bot]`
4. Use the webhook installation ID to mint an installation token
5. Query review threads and resolve only `isOutdated && !isResolved` threads
6. Optionally post a summary comment back to the PR

## Files

| File | Purpose |
|---|---|
| `.github/cloudflare/copilot-review-thread-resolver-worker.mjs` | Single-file Cloudflare Worker to copy into a Worker project |
| `docs/plans/2026-04-02-08-34-UTC-cloudflare-github-app-review-thread-resolver.md` | This plan |

## GitHub App setup

- Webhook events: `issue_comment`
- Permissions:
  - `Metadata: Read`
  - `Pull requests: Write`
  - `Issues: Write`

## Worker secrets

- `GITHUB_APP_ID`
- `GITHUB_APP_PRIVATE_KEY`
- `GITHUB_WEBHOOK_SECRET`

## Notes

- No filtering by comment body text; identity-only filtering keeps the trigger robust.
- The resolve operation is idempotent because already-resolved or non-outdated threads are skipped.
- The Worker file is intentionally dependency-free so it can be pasted directly into Cloudflare.
