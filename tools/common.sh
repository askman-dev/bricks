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
