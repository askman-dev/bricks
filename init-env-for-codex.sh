#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/.local/flutter}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

print_step() {
  echo "[init-env-for-codex] $1"
}

ensure_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

append_path_if_needed() {
  local dir="$1"
  if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
    export PATH="$dir:$PATH"
  fi
}

install_flutter_if_missing() {
  if command -v flutter >/dev/null 2>&1; then
    return
  fi

  ensure_cmd git

  print_step "Installing Flutter ($FLUTTER_CHANNEL) into $FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"

  if [[ -d "$FLUTTER_HOME/.git" ]]; then
    git -C "$FLUTTER_HOME" fetch --all --tags
    git -C "$FLUTTER_HOME" checkout "$FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" pull --ff-only
  else
    rm -rf "$FLUTTER_HOME"
    git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
  fi
}

install_melos_if_missing() {
  if command -v melos >/dev/null 2>&1; then
    print_step "Melos already installed: $(melos --version 2>/dev/null || echo unknown)"
    return
  fi

  print_step "Installing melos via dart pub global activate melos"
  dart pub global activate melos
}

main() {
  print_step "Repository root: $ROOT_DIR"

  ensure_cmd bash
  ensure_cmd git

  install_flutter_if_missing
  append_path_if_needed "$FLUTTER_HOME/bin"
  append_path_if_needed "$HOME/.pub-cache/bin"

  ensure_cmd flutter
  ensure_cmd dart

  install_melos_if_missing
  append_path_if_needed "$HOME/.pub-cache/bin"
  ensure_cmd melos

  print_step "Environment ready."
  print_step "Try: melos --version"
  print_step "Then: melos bootstrap && melos analyze"
}

main "$@"
