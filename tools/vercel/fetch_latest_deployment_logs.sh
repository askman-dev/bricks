#!/usr/bin/env bash
set -euo pipefail

TEAM_ID="${TEAM_ID:-team_r9AW1oyPBmobWS7diUr7oYlz}"
PROJECT_ID="${PROJECT_ID:-prj_clgP2QZnYLQxJuRrSVIiDjv612t4}"
LIMIT="${1:-10}"

if [[ -z "${VERCEL_TOKEN:-}" ]]; then
  echo "ERROR: VERCEL_TOKEN is required" >&2
  exit 1
fi

DEPLOY_UID=$(curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v6/deployments?teamId=${TEAM_ID}&projectId=${PROJECT_ID}&limit=1" \
  | jq -r '.deployments[0].uid')

if [[ -z "$DEPLOY_UID" || "$DEPLOY_UID" == "null" ]]; then
  echo "ERROR: Could not find latest deployment uid" >&2
  exit 1
fi

curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v3/deployments/${DEPLOY_UID}/events?teamId=${TEAM_ID}&limit=1000" \
  | jq --argjson limit "$LIMIT" '
    sort_by(.created)
    | reverse
    | .[:$limit]
    | map({
        created_utc: (.created / 1000 | strftime("%Y-%m-%dT%H:%M:%SZ")),
        type,
        text,
        deploymentId,
        id
      })
  '
