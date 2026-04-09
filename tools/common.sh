#!/usr/bin/env bash

# Common shell functions for Bricks scripts
# This file contains reusable validation and helper functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions for output
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure a command exists, otherwise print actionable error and exit.
ensure_cmd() {
    local cmd="$1"
    local hint="${2:-Please install ${cmd} and ensure it is in PATH.}"

    if ! command_exists "$cmd"; then
        print_error "Missing required command: ${cmd}"
        echo "$hint"
        exit 1
    fi
}

# Ensure a command exists, and try best-effort installation with npm when requested.
ensure_or_install_cmd() {
    local cmd="$1"
    local npm_package="${2:-$1}"
    local hint="${3:-Please install ${cmd} manually and rerun.}"
    local install_output
    local npm_global_bin=""

    if command_exists "$cmd"; then
        return 0
    fi

    if ! command_exists npm; then
        print_error "Cannot auto-install ${cmd}: npm is not installed or not in PATH."
        echo "$hint"
        exit 1
    fi

    print_warning "${cmd} not found. Attempting npm global install: ${npm_package}"
    if npm install -g "$npm_package" >/dev/null 2>&1; then
        if command_exists "$cmd"; then
            print_success "Installed ${cmd} via npm."
            return 0
        fi

        npm_global_bin="$(npm bin -g 2>/dev/null || true)"
        print_error "Installed ${npm_package} via npm, but ${cmd} is still not in PATH."
        if [ -n "$npm_global_bin" ]; then
            echo "Add npm's global bin directory to PATH: ${npm_global_bin}"
        else
            echo "Add npm's global bin directory to PATH and rerun."
        fi
        echo "$hint"
        exit 1
    fi

    print_error "Failed to auto-install ${cmd}."
    echo "$hint"
    if [ -n "$install_output" ]; then
        echo "npm install output:" >&2
        echo "$install_output" >&2
    fi
    exit 1
}

# Check prerequisites (Flutter, Dart, Melos)
check_prerequisites() {
    print_step "Checking prerequisites..."

    local missing_tools=()

    if ! command_exists flutter; then
        missing_tools+=("flutter")
    else
        print_success "Flutter installed: $(flutter --version | head -n1)"
    fi

    if ! command_exists dart; then
        missing_tools+=("dart")
    else
        print_success "Dart installed: $(dart --version 2>&1 | head -n1)"
    fi

    if ! command_exists melos; then
        if command_exists dart; then
            print_warning "Melos not installed. Installing..."
            dart pub global activate melos
            print_success "Melos installed"
        else
            print_warning "Melos not installed (requires Dart to install)"
        fi
    else
        print_success "Melos installed: $(melos --version 2>&1 || echo 'unknown version')"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                flutter)
                    echo "  - Flutter: https://docs.flutter.dev/get-started/install"
                    ;;
                dart)
                    echo "  - Dart: https://dart.dev/get-dart"
                    ;;
            esac
        done
        return 1
    fi

    echo ""
    return 0
}
