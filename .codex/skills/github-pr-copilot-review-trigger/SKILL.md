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

`@copilot Please go through **every** PR review comment one by one—do not skip any. For each comment, you must post a reply regardless of whether you act on it or not. If a comment requires a code change, commit the fix and reply explaining what you changed. If a comment should be ignored, still reply with a clear explanation of your reasoning—describe why the suggestion is not necessary or not applicable in this context. After replying to every comment, mark all of them as resolved.`

## Failure handling

- If API returns 401/403, tell the user token permissions are insufficient.
- Mention required permissions for commenting are typically `issues:write` (or Pull Requests write on fine-grained PATs).
- Keep token values redacted in logs and responses.
