---
name: vercel-api-log-context
description: Fetch and analyze Vercel deployment logs through API to debug frontend/backend errors with additional context. Use when a user provides a Vercel logs link, deployment URL, request id, or reports production/preview errors that need recent log evidence.
---

# Vercel API Log Context

Use shell tooling only (`bash`, `curl`, `jq`, `rg`). Do not rely on Python helpers.

## 1) Validate access and identifiers
1. Ensure `VERCEL_TOKEN` is available.
2. Resolve `teamId` and `projectId` when missing.
3. If a dashboard URL is provided, parse `selectedLogId` and timestamp for time-window targeting.

## 2) Pull latest deployment logs (default path)
Run:

```bash
tools/vercel/fetch_latest_deployment_logs.sh 10
```

This returns the latest 10 log events in descending time order.

## 3) Deepen context for reported frontend errors
When a user reports a frontend error:
1. Capture error text, route, time, environment (preview/production).
2. Pull latest deployment logs first.
3. If needed, fetch more events (e.g. 50/100) and filter by:
   - `error`, `TypeError`, `TS`, `500`, `timeout`, `failed`
   - route/function related keywords
4. Correlate log timestamps with the user's reported time.
5. Summarize likely root cause + confidence + missing data.

## 4) Command snippets
Get latest deployment uid:

```bash
TEAM_ID='<team_id>'
PROJECT_ID='<project_id>'
curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v6/deployments?teamId=$TEAM_ID&projectId=$PROJECT_ID&limit=1" \
  | jq -r '.deployments[0].uid'
```

Get events for a deployment:

```bash
DEPLOY_UID='<deployment_uid>'
curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v3/deployments/$DEPLOY_UID/events?teamId=$TEAM_ID&limit=1000"
```

Get last 10 sorted by time:

```bash
curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" "https://api.vercel.com/v3/deployments/$DEPLOY_UID/events?teamId=$TEAM_ID&limit=1000" \
  | jq 'sort_by(.created) | reverse | .[:10]'
```

## 5) Output format
Return:
1. Time range checked (UTC)
2. Last 10 logs (structured)
3. Error-correlated lines
4. Next action (code fix / config fix / additional logs needed)
