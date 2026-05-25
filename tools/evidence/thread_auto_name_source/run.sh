#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CASE_DIR="$ROOT_DIR/tools/evidence/thread_auto_name_source"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
EVIDENCE_DIR="$ROOT_DIR/.cache/evidence/thread-auto-name-source/$RUN_ID"
BACKEND_DIR="$ROOT_DIR/apps/node_backend"
BACKEND_STARTED=0
BACKEND_PID=""

mkdir -p "$EVIDENCE_DIR"
REQUESTED_PORT="${PORT:-}"
REQUESTED_API_BASE_URL="${BRICKS_API_BASE_URL:-}"

cleanup() {
  local status=$?
  if [[ "${KEEP_SERVICES:-0}" != "1" ]]; then
    if [[ "$BACKEND_STARTED" == "1" && -n "$BACKEND_PID" ]]; then
      kill "$BACKEND_PID" >/dev/null 2>&1 || true
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

if [[ ! -f "$ROOT_DIR/.env.local" ]]; then
  echo "Missing $ROOT_DIR/.env.local" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$ROOT_DIR/.env.local"
set +a

export PORT="${REQUESTED_PORT:-${PORT:-3011}}"
export BRICKS_API_BASE_URL="${REQUESTED_API_BASE_URL:-http://127.0.0.1:$PORT}"
export REPO_ROOT="$ROOT_DIR"
export RUN_ID
export EVIDENCE_DIR
export NODE_ENV="${NODE_ENV:-development}"
export BRICKS_LOCAL_DEV="${BRICKS_LOCAL_DEV:-true}"
if [[ -n "${GEMINI_API_KEY:-}" && -z "${LOCAL_LLM_CONFIG_ENABLED:-}" ]]; then
  export LOCAL_LLM_CONFIG_ENABLED=true
fi

required_vars=(
  BRICKS_TEST_TOKEN
  FIXTURE_USER_ID
  JWT_SECRET
  BRICKS_API_BASE_URL
)

for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
done

http_code() {
  curl -sS -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts="${3:-90}"
  for _ in $(seq 1 "$attempts"); do
    if [[ "$(http_code "$url")" == "200" ]]; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

if [[ "${RUN_MIGRATIONS:-1}" == "1" ]]; then
  (
    cd "$BACKEND_DIR"
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env.local"
    set +a
    npx tsx src/db/migrate.ts
  ) >"$EVIDENCE_DIR/$RUN_ID-migrate.log" 2>&1
fi

if [[ "$(http_code "$BRICKS_API_BASE_URL/api/health")" != "200" ]]; then
  (
    cd "$BACKEND_DIR"
    PORT="$PORT" AUTO_MIGRATE="${AUTO_MIGRATE:-false}" npm run dev
  ) >"$EVIDENCE_DIR/$RUN_ID-backend.log" 2>&1 &
  BACKEND_PID="$!"
  BACKEND_STARTED=1
fi

wait_for_http "$BRICKS_API_BASE_URL/api/health" "backend"

node "$CASE_DIR/thread_auto_name_flow.mjs"

echo
echo "Evidence: $EVIDENCE_DIR"
if [[ -f "$EVIDENCE_DIR/summary.json" ]]; then
  node -e "const fs=require('node:fs'); const s=JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); console.log(JSON.stringify(s, null, 2));" "$EVIDENCE_DIR/summary.json"
fi
