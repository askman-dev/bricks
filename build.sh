#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tools/common.sh"

print_step "Installing dependencies"
npm --prefix apps/web_chat_app ci
npm --prefix apps/node_backend ci

print_step "Running frontend tests"
npm --prefix apps/web_chat_app run test

print_step "Building frontend"
npm --prefix apps/web_chat_app run build

print_success "Build completed"
echo "Web build output: apps/web_chat_app/dist"
