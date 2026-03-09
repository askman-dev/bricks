#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_BOOTSTRAP=1
RUN_DOCTOR=1
FLUTTER_CHANNEL="stable"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/.local/flutter}"

print_help() {
  cat <<'USAGE'
Usage: tools/init_dev_env.sh [options]

Initialize local development environment for the Bricks monorepo.

Options:
  --no-bootstrap       Skip `melos bootstrap`.
  --no-doctor          Skip `flutter doctor -v`.
  --flutter-home PATH  Flutter installation location (default: $HOME/.local/flutter or $FLUTTER_HOME).
  --channel NAME       Flutter channel to install when missing (default: stable).
  -h, --help           Show this help message.
USAGE
}

log() {
  printf '[init] %s\n' "$*"
}

fail() {
  printf '[init][error] %s\n' "$*" >&2
  exit 1
}

ensure_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: $cmd. $hint"
  fi
}

append_to_path_if_dir() {
  local dir="$1"
  if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
    export PATH="$dir:$PATH"
  fi
}

persist_shell_path_hint() {
  local flutter_bin="$1"
  if [[ -n "${SHELL:-}" ]]; then
    log "If needed, add Flutter to your shell profile: export PATH=\"$flutter_bin:\$PATH\""
  fi
}

install_flutter_if_missing() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  ensure_cmd git "Git is required to install Flutter automatically."

  log "Flutter not found. Installing Flutter ($FLUTTER_CHANNEL) to: $FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"

  if [[ -d "$FLUTTER_HOME/.git" ]]; then
    log "Existing Flutter git checkout detected. Updating channel: $FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" fetch --all --tags
    git -C "$FLUTTER_HOME" checkout "$FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" pull --ff-only
  else
    rm -rf "$FLUTTER_HOME"
    git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
  fi

  append_to_path_if_dir "$FLUTTER_HOME/bin"
  persist_shell_path_hint "$FLUTTER_HOME/bin"

  ensure_cmd flutter "Flutter installation failed."
}

while (($#)); do
  case "$1" in
    --no-bootstrap)
      RUN_BOOTSTRAP=0
      ;;
    --no-doctor)
      RUN_DOCTOR=0
      ;;
    --flutter-home)
      shift
      [[ $# -gt 0 ]] || fail "--flutter-home requires a path argument."
      FLUTTER_HOME="$1"
      ;;
    --channel)
      shift
      [[ $# -gt 0 ]] || fail "--channel requires a value."
      FLUTTER_CHANNEL="$1"
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      fail "Unknown option: $1. Use --help to see available options."
      ;;
  esac
  shift
done

log "Repository root: $ROOT_DIR"
ensure_cmd git "Please install Git first."
ensure_cmd bash "Please use a shell environment with bash available."

install_flutter_if_missing
append_to_path_if_dir "$FLUTTER_HOME/bin"

ensure_cmd flutter "Install Flutter SDK >= 3.x and ensure it is in PATH."
ensure_cmd dart "Dart is bundled with Flutter; ensure Flutter bin is in PATH."

if command -v melos >/dev/null 2>&1; then
  log "Melos already installed: $(melos --version)"
else
  log "Melos not found in PATH. Installing via: dart pub global activate melos"
  dart pub global activate melos
  append_to_path_if_dir "$HOME/.pub-cache/bin"
fi

ensure_cmd melos "Run 'dart pub global activate melos' and add \"$HOME/.pub-cache/bin\" to PATH."

if [[ "$RUN_DOCTOR" -eq 1 ]]; then
  log "Running flutter doctor"
  flutter doctor -v || log "flutter doctor reported issues; continuing."
fi

if [[ "$RUN_BOOTSTRAP" -eq 1 ]]; then
  log "Running melos bootstrap"
  (cd "$ROOT_DIR" && melos bootstrap)
fi

log "Initialization completed successfully."
