#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <owner/repo> <pr_number> [comment_body]" >&2
  exit 2
fi

repo="$1"
pr_number="$2"
comment_body="${3:-@copilot Please go through the PR review comments and address them. Use your own judgment—don't just blindly follow the suggestions. Commit code for the necessary fixes, but for comments you think should be ignored, just leave a reply explaining your reasoning. Make sure to mark all comments as resolved once you're done.}"

token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "$token" ]]; then
  echo "Error: GH_TOKEN or GITHUB_TOKEN is required." >&2
  exit 2
fi

api_url="https://api.github.com/repos/${repo}/issues/${pr_number}/comments"
headers_file="$(mktemp)"
body_file="$(mktemp)"
cleanup() {
  rm -f "$headers_file" "$body_file"
}
trap cleanup EXIT

payload="$(jq -nc --arg body "$comment_body" '{body:$body}')"
http_code="$(curl -sS -D "$headers_file" -o "$body_file" -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer ${token}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api_url" \
  -d "$payload")"

if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
  html_url="$(jq -r '.html_url // empty' "$body_file")"
  echo "Comment posted successfully.${html_url:+ URL: $html_url}"
  exit 0
fi

echo "Failed to post PR comment. HTTP $http_code" >&2
accepted_permissions="$(awk -F': ' 'tolower($1)=="x-accepted-github-permissions" {print $2}' "$headers_file" | tr -d '\r')"
if [[ -n "$accepted_permissions" ]]; then
  echo "x-accepted-github-permissions: $accepted_permissions" >&2
fi
jq -r '.message // "Unknown API error"' "$body_file" >&2
exit 1
