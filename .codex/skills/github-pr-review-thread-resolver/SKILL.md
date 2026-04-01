---
name: github-pr-review-thread-resolver
description: Resolve GitHub pull request review threads (especially outdated threads) through GraphQL mutations. Use when a PR is in REVIEW_FIXED state and unresolved review threads should be cleaned up without re-triggering Copilot review comments.
---

Resolve review threads on a GitHub pull request with a bash script.

## Steps

1. Confirm repository and PR number.
2. Confirm token availability:
   - Prefer `GH_TOKEN`.
   - Fallback to `GITHUB_TOKEN`.
3. Ensure `jq` and `curl` are installed in the runtime.
4. Start with dry-run (outdated mode by default):
   ```bash
   ./.codex/skills/github-pr-review-thread-resolver/scripts/resolve_review_threads.sh \
     <owner/repo> <pr_number> --dry-run
   ```
5. If results are correct, run live mode:
   ```bash
   ./.codex/skills/github-pr-review-thread-resolver/scripts/resolve_review_threads.sh \
     <owner/repo> <pr_number>
   ```

## Modes

- `--mode outdated` (default): resolve only unresolved + outdated threads.
- `--mode unresolved`: resolve all unresolved threads.
- `--mode all`: same as unresolved for explicit intent.

## Safety

- Always run `--dry-run` first.
- Do not resolve active discussion threads unless explicitly requested.
- If API returns 401/403, report insufficient token permissions.
