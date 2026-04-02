# Plan: GitHub webhook / Cloudflare worker skill

## Background

This repository now has an external Cloudflare Worker path for GitHub PR automation, but future agents may not discover that capability unless it is documented in the repository's skill system and surfaced in the main agent instructions.

## Goals

- Add a Codex skill that explains the repository's GitHub webhook to Cloudflare Worker integration.
- Document where the Worker code lives, how it is deployed, and how the GitHub webhook links to it.
- Make future agents more likely to choose this path when working on Copilot PR automation or external webhook debugging.

## Implementation Plan

### Phase 1: Add a repository skill

- Create `.codex/skills/github-webhook-cloudflare-worker/SKILL.md`.
- Describe the current Worker source, Wrangler project, deployed URL, webhook endpoint, auth modes, and debugging commands.
- Explain when to use `issue_comment`, `pull_request:synchronize`, and `push`.

### Phase 2: Surface the skill in repository instructions

- Update `AGENTS.md` with a short note telling agents to use the new skill first when working on Copilot PR automation that must avoid GitHub Actions approval gates.

### Phase 3: Validate repository references

- Confirm the skill points to the real repository paths under `.github/cloudflare/`.
- Confirm the documented commands are consistent with the Wrangler project layout.

## Acceptance Criteria

- A new skill exists at `.codex/skills/github-webhook-cloudflare-worker/SKILL.md`.
- `AGENTS.md` explicitly points future agents to the new skill.
- The skill explains the relationship between the GitHub repository webhook and the Cloudflare Worker endpoints.
- The skill includes concrete operational commands for checking, deploying, and debugging the Worker.
