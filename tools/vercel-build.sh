#!/usr/bin/env bash
set -euo pipefail

INSTALL_ONLY="${1:-}"

if [ "${INSTALL_ONLY}" = "--install-only" ]; then
  echo "Installing web frontend dependencies..."
  npm --prefix apps/web_chat_app ci
  exit 0
fi

npm --prefix apps/web_chat_app run build
