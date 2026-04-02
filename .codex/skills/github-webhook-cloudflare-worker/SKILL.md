---
name: github-webhook-cloudflare-worker
description: Understand, operate, and extend this repository's GitHub webhook to Cloudflare Worker integration for Copilot PR automation. Use when a user asks about the external webhook path, the Worker URL, repo webhook setup, Wrangler deployment, or adding triggers such as pull_request synchronize or push.
---

Manage the repository's external GitHub webhook + Cloudflare Worker path.

## Purpose

This repository uses an external Cloudflare Worker to handle Copilot-driven PR automation that should not depend on GitHub Actions workflow approval. The Worker receives GitHub repository webhooks directly, verifies signatures, filters the relevant Copilot events, and then calls the GitHub API to resolve outdated PR review threads.

## Current implementation

### Files

- Worker source: `.github/cloudflare/copilot-review-thread-resolver-worker.mjs`
- Wrangler project root: `.github/cloudflare/`
- Wrangler config: `.github/cloudflare/wrangler.toml`

### Current endpoints

- Base URL: `https://askman-bricks-copilot-review-resolver-hook.itzy.workers.dev`
- Health check: `https://askman-bricks-copilot-review-resolver-hook.itzy.workers.dev/healthz`
- GitHub webhook target: `https://askman-bricks-copilot-review-resolver-hook.itzy.workers.dev/github/webhook`

### Current behavior

- GitHub repository webhook sends `issue_comment` events to the Worker.
- The Worker only processes comments on pull requests.
- The Worker filters by identity for `copilot-swe-agent[bot]`; it does **not** rely on comment body text.
- The Worker resolves only `isOutdated && !isResolved` review threads, so repeated delivery is safe and idempotent.

### Auth modes supported by the Worker

Choose one:

1. Direct token mode:
   - `GITHUB_TOKEN` or `GH_TOKEN`
2. GitHub App mode:
   - `GITHUB_APP_ID`
   - `GITHUB_APP_PRIVATE_KEY`

Always required:

- `GITHUB_WEBHOOK_SECRET`

## When to use this skill

Use this skill when the user asks to:

- debug or inspect the Cloudflare Worker deployment
- verify the Worker URL or repo webhook configuration
- redeploy the Worker with Wrangler
- extend webhook triggers beyond `issue_comment`
- reason about how GitHub webhook events connect to the external Worker
- avoid GitHub Actions approval gates for Copilot-triggered automation

## Standard operating steps

1. Inspect the current Worker code and Wrangler project:
   ```bash
   cd .github/cloudflare
   npm run check
   ```
2. Verify Cloudflare auth:
   ```bash
   cd .github/cloudflare
   npx wrangler whoami
   ```
3. Deploy the latest Worker:
   ```bash
   cd .github/cloudflare
   npx wrangler deploy
   ```
4. Verify health:
   ```bash
   curl -s https://askman-bricks-copilot-review-resolver-hook.itzy.workers.dev/healthz
   ```
5. Inspect repository webhooks:
   ```bash
   gh api repos/askman-dev/bricks/hooks
   ```
6. Re-ping a webhook delivery if needed:
   ```bash
   gh api repos/askman-dev/bricks/hooks/<hook_id>/pings -X POST
   ```

## Extending triggers

### Recommended trigger order

1. `issue_comment`
   - Best for "Copilot has finished and commented on the PR"
   - Good place for visible summary comments
2. `pull_request` with `action=synchronize`
   - Best for "an existing PR received a new commit"
   - Preferred over raw `push` because the PR number is already in the payload
3. `push`
   - Broad fallback only
   - Requires branch-to-PR lookup and extra filtering

### Guidance

- Prefer `pull_request:synchronize` over `push` when you need to react to commits on an existing PR.
- If adding `push`, keep that path silent (no visible comment spam) and use it as a background safety net.
- Keep `issue_comment` as the user-visible trigger for summary comments.
- Remember: GitHub does **not** emit a dedicated event for "review thread became outdated"; every trigger must still query GraphQL for `isOutdated`.

## Safety rules

- Do not rely on Copilot comment text such as `Addressed in ...`.
- Filter by sender identity and event shape instead.
- Keep the resolver idempotent by resolving only unresolved outdated threads.
- Prefer Worker secrets over repository-committed credentials.
- If the user asks to move this logic back into GitHub Actions, explain the Copilot workflow approval gate tradeoff first.

## Useful troubleshooting checklist

1. Worker health returns `200` from `/healthz`.
2. `wrangler whoami` succeeds.
3. The repo webhook exists and points to `/github/webhook`.
4. The latest webhook delivery is `200 OK`.
5. Worker secrets are present in Cloudflare.
6. The incoming event is one the Worker actually handles.
