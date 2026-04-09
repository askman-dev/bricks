#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

print_step "Repository root: $ROOT_DIR"

ensure_cmd git "Please install Git first."
ensure_or_install_cmd curl curl "Install curl manually."
ensure_or_install_cmd jq jq "Install jq manually."
ensure_cmd node "Install Node.js 20+ and ensure it is in PATH."
ensure_cmd npm "Install npm and ensure it is in PATH."

print_step "Installing backend dependencies"
npm --prefix "$ROOT_DIR/apps/node_backend" ci

print_step "Installing React frontend dependencies"
npm --prefix "$ROOT_DIR/apps/web_chat_app" ci

print_success "Development environment initialized"
echo "Next steps:"
echo "  1. Frontend tests: npm --prefix apps/web_chat_app run test"
echo "  2. Frontend dev server: npm --prefix apps/web_chat_app run dev"
echo "  3. Backend dev server: npm --prefix apps/node_backend run dev"
