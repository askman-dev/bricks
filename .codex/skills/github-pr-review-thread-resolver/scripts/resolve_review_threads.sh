#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 <owner/repo> <pr_number> [--mode outdated|unresolved|all] [--dry-run]

Defaults:
  --mode outdated
USAGE
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

REPO="$1"
PR_NUMBER="$2"
shift 2

MODE="outdated"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift 1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "outdated" && "$MODE" != "unresolved" && "$MODE" != "all" ]]; then
  echo "Invalid mode: $MODE" >&2
  exit 1
fi

if [[ "$REPO" != */* ]]; then
  echo "repo must be owner/repo" >&2
  exit 1
fi

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "$TOKEN" ]]; then
  echo "Missing GH_TOKEN or GITHUB_TOKEN" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO#*/}"

graphql_call() {
  local query="$1"
  local variables="$2"

  curl -sS https://api.github.com/graphql \
    -H "Authorization: bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "User-Agent: codex-skill-github-pr-review-thread-resolver" \
    --data-binary "$(jq -nc --arg query "$query" --argjson variables "$variables" '{query:$query,variables:$variables}')"
}

QUERY_THREADS='query($owner:String!, $repo:String!, $pr:Int!, $cursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100, after:$cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          comments(first:1) {
            nodes {
              url
              author { login }
            }
          }
        }
      }
    }
  }
}'

MUTATION_RESOLVE='mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread { id isResolved isOutdated }
  }
}'

THREADS_FILE="$(mktemp)"
trap 'rm -f "$THREADS_FILE"' EXIT
printf '[]' > "$THREADS_FILE"

CURSOR="null"
while :; do
  VARS="$(jq -nc --arg owner "$OWNER" --arg repo "$REPO_NAME" --argjson pr "$PR_NUMBER" --argjson cursor "$CURSOR" '{owner:$owner,repo:$repo,pr:$pr,cursor:$cursor}')"
  RESPONSE="$(graphql_call "$QUERY_THREADS" "$VARS")"

  if jq -e '.errors' >/dev/null <<<"$RESPONSE"; then
    jq '.errors' <<<"$RESPONSE" >&2
    exit 1
  fi

  PR_NODE="$(jq '.data.repository.pullRequest' <<<"$RESPONSE")"
  if [[ "$PR_NODE" == "null" ]]; then
    echo "Pull request not found: $REPO#$PR_NUMBER" >&2
    exit 1
  fi

  NODES="$(jq '.data.repository.pullRequest.reviewThreads.nodes' <<<"$RESPONSE")"
  jq -s '.[0] + .[1]' "$THREADS_FILE" <(printf '%s' "$NODES") > "$THREADS_FILE.tmp"
  mv "$THREADS_FILE.tmp" "$THREADS_FILE"

  HAS_NEXT="$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"$RESPONSE")"
  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi
  CURSOR="$(jq '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' <<<"$RESPONSE")"
done

SELECTED_FILE="$(mktemp)"
trap 'rm -f "$THREADS_FILE" "$SELECTED_FILE"' EXIT

case "$MODE" in
  outdated)
    jq '[.[] | select((.isResolved|not) and .isOutdated)]' "$THREADS_FILE" > "$SELECTED_FILE"
    ;;
  unresolved|all)
    jq '[.[] | select(.isResolved|not)]' "$THREADS_FILE" > "$SELECTED_FILE"
    ;;
esac

TOTAL_THREADS="$(jq 'length' "$THREADS_FILE")"
SELECTED_THREADS="$(jq 'length' "$SELECTED_FILE")"

echo "total_threads=$TOTAL_THREADS selected_threads=$SELECTED_THREADS mode=$MODE dry_run=$DRY_RUN"

jq -r '
  to_entries[] |
  "[\(.key + 1)] id=\(.value.id) isOutdated=\(.value.isOutdated) isResolved=\(.value.isResolved) author=\(.value.comments.nodes[0].author.login // "") url=\(.value.comments.nodes[0].url // "")"
' "$SELECTED_FILE"

if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi

RESOLVED=0
while IFS= read -r THREAD_ID; do
  [[ -z "$THREAD_ID" ]] && continue
  VARS="$(jq -nc --arg threadId "$THREAD_ID" '{threadId:$threadId}')"
  RESPONSE="$(graphql_call "$MUTATION_RESOLVE" "$VARS")"
  if jq -e '.errors' >/dev/null <<<"$RESPONSE"; then
    jq '.errors' <<<"$RESPONSE" >&2
    exit 1
  fi
  RESOLVED=$((RESOLVED + 1))
done < <(jq -r '.[].id' "$SELECTED_FILE")

echo "resolved_threads=$RESOLVED"
