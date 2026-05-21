#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CASE_DIR="$ROOT_DIR/tools/evidence/channel_dropdown_height"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
EVIDENCE_DIR="$ROOT_DIR/.cache/evidence/channel-dropdown-height/$RUN_ID"
RUNNER_DIR="$ROOT_DIR/.cache/evidence/channel-dropdown-height/.runner"
BACKEND_DIR="$ROOT_DIR/apps/node_backend"
FLUTTER_DIR="$ROOT_DIR/apps/mobile_chat_app"
BACKEND_STARTED=0
WEB_STARTED=0
BACKEND_PID=""
WEB_PID=""

mkdir -p "$EVIDENCE_DIR" "$RUNNER_DIR"

cleanup() {
  local status=$?
  if [[ "${KEEP_SERVICES:-0}" != "1" ]]; then
    if [[ "$WEB_STARTED" == "1" && -n "$WEB_PID" ]]; then
      kill "$WEB_PID" >/dev/null 2>&1 || true
    fi
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

export PORT="${PORT:-3010}"
export BRICKS_API_BASE_URL="${BRICKS_API_BASE_URL:-http://127.0.0.1:$PORT}"
export BRICKS_WEB_URL="${BRICKS_WEB_URL:-http://127.0.0.1:8082}"
export BRICKS_WEB_PORT="${BRICKS_WEB_PORT:-8082}"
export RUN_ID
export EVIDENCE_DIR
export HARNESS_RUNNER_DIR="$RUNNER_DIR"

required_vars=(
  TURSO_DATABASE_URL
  TURSO_AUTH_TOKEN
  JWT_SECRET
  BRICKS_TEST_TOKEN
  BRICKS_API_BASE_URL
  FIXTURE_USER_ID
)

for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
done

http_ok() {
  local url="$1"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  [[ "$code" == "200" ]]
}

wait_for_http() {
  local url="$1"
  local label="$2"
  local attempts="${3:-90}"
  for _ in $(seq 1 "$attempts"); do
    if http_ok "$url"; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for $label at $url" >&2
  return 1
}

prepare_runner_deps() {
  if [[ ! -f "$RUNNER_DIR/package.json" ]]; then
    cat > "$RUNNER_DIR/package.json" <<'JSON'
{
  "private": true,
  "type": "module",
  "dependencies": {
    "playwright": "^1.57.0",
    "pngjs": "^7.0.0"
  }
}
JSON
  fi
  if [[ ! -d "$RUNNER_DIR/node_modules/playwright" || ! -d "$RUNNER_DIR/node_modules/pngjs" ]]; then
    (cd "$RUNNER_DIR" && npm install)
  fi
  (cd "$RUNNER_DIR" && npx playwright install chromium >/dev/null)
}

start_backend_if_needed() {
  if http_ok "$BRICKS_API_BASE_URL/api/health"; then
    echo "Backend already ready: $BRICKS_API_BASE_URL"
    return 0
  fi
  echo "Starting backend on $BRICKS_API_BASE_URL"
  (
    cd "$BACKEND_DIR"
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env.local"
    set +a
    AUTO_MIGRATE="${AUTO_MIGRATE:-false}" npm run dev
  ) >"$EVIDENCE_DIR/$RUN_ID-backend.log" 2>&1 &
  BACKEND_PID="$!"
  BACKEND_STARTED=1
  wait_for_http "$BRICKS_API_BASE_URL/api/health" "backend"
}

start_web_if_needed() {
  if http_ok "$BRICKS_WEB_URL/"; then
    echo "Flutter web already ready: $BRICKS_WEB_URL"
    return 0
  fi
  echo "Building Flutter web debug bundle"
  (
    cd "$FLUTTER_DIR"
    flutter build web --debug \
      --dart-define=BRICKS_API_BASE_URL="$BRICKS_API_BASE_URL" \
      --dart-define=BRICKS_TEST_TOKEN="$BRICKS_TEST_TOKEN"
  ) >"$EVIDENCE_DIR/$RUN_ID-flutter-build.log" 2>&1

  echo "Starting Flutter static web server on $BRICKS_WEB_URL"
  (
    node "$ROOT_DIR/tools/evidence/channel_new_ui_harness/static_server.mjs" \
      "$FLUTTER_DIR/build/web" \
      "$BRICKS_WEB_PORT"
  ) >"$EVIDENCE_DIR/$RUN_ID-flutter.log" 2>&1 &
  WEB_PID="$!"
  WEB_STARTED=1
  wait_for_http "$BRICKS_WEB_URL/" "Flutter web" 30
}

prepare_runner_deps
start_backend_if_needed
start_web_if_needed

node "$CASE_DIR/channel_dropdown_flow.mjs"

echo
echo "Evidence: $EVIDENCE_DIR"
if [[ -f "$EVIDENCE_DIR/summary.json" ]]; then
  node -e "const s=require(process.argv[1]); console.log(JSON.stringify(s, null, 2));" "$EVIDENCE_DIR/summary.json"
fi
