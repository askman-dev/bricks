---
name: github-pr-copilot-review-trigger
description: Post a pull request comment that triggers Copilot to process review comments. Use when the user asks to add or replay an @copilot instruction comment on a GitHub PR, especially to ask Copilot to address review feedback and resolve comments.
---

Post a Copilot-triggering comment to a GitHub pull request.

## Steps

1. Confirm the target repository and PR number.
2. Confirm token availability:
   - Prefer `GH_TOKEN`.
   - Fallback to `GITHUB_TOKEN`.
3. Run the bundled script:
   ```bash
   ./.codex/skills/github-pr-copilot-review-trigger/scripts/post_copilot_review_comment.sh \
     <owner/repo> <pr_number>
   ```
4. If the user provides custom comment content, pass it as the third argument:
   ```bash
   ./.codex/skills/github-pr-copilot-review-trigger/scripts/post_copilot_review_comment.sh \
     <owner/repo> <pr_number> "<custom-comment>"
   ```
5. Report the returned comment URL.

## Default comment text

When no custom text is provided, use:

`@copilot Please go through the PR review comments and address them. Use your own judgment—don't just blindly follow the suggestions. Commit code for the necessary fixes, but for comments you think should be ignored, just leave a reply explaining your reasoning. Make sure to mark all comments as resolved once you're done.`

## Failure handling

- If API returns 401/403, tell the user token permissions are insufficient.
- Mention required permissions for commenting are typically `issues:write` (or Pull Requests write on fine-grained PATs).
- Keep token values redacted in logs and responses.
