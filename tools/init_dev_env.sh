#!/usr/bin/env bash

# Initialize Development Environment Script
# This script sets up a development environment for the Bricks monorepo

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common.sh"

# Configuration
RUN_BOOTSTRAP=1
RUN_DOCTOR=1
FLUTTER_CHANNEL="stable"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/.local/flutter}"

# Display banner
show_banner() {
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║    Bricks Development Environment Setup              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
}

print_help() {
  cat <<'USAGE'
Usage: tools/init_dev_env.sh [options]

Initialize local/Codex development environment for the Bricks monorepo.

Options:
  --no-bootstrap       Skip `melos bootstrap`.
  --no-doctor          Skip `flutter doctor -v`.
  --flutter-home PATH  Flutter installation location (default: $HOME/.local/flutter or $FLUTTER_HOME).
  --channel NAME       Flutter channel to install when missing (default: stable).
  -h, --help           Show this help message.

Examples:
  ./tools/init_dev_env.sh
  ./tools/init_dev_env.sh --no-bootstrap --no-doctor
USAGE
}

ensure_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command_exists "$cmd"; then
    print_error "Missing required command: $cmd. $hint"
    exit 1
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
    print_step "If needed, add Flutter to your shell profile: export PATH=\"$flutter_bin:\$PATH\""
  fi
}

ensure_flutter_shims() {
  local flutter_bin="$1"
  local shim_dir="$HOME/.local/bin"
  local created=0

  mkdir -p "$shim_dir"

  if [[ -x "$flutter_bin/flutter" ]]; then
    ln -snf "$flutter_bin/flutter" "$shim_dir/flutter"
    created=1
  fi

  if [[ -x "$flutter_bin/dart" ]]; then
    ln -snf "$flutter_bin/dart" "$shim_dir/dart"
    created=1
  fi

  if [[ "$created" -eq 1 ]]; then
    append_to_path_if_dir "$shim_dir"
    print_step "Created/updated Flutter shims in: $shim_dir"
    print_step "If needed, add shims to your shell profile: export PATH=\"$shim_dir:\$PATH\""
  else
    print_warning "No flutter/dart executables found in $flutter_bin; skipping shim creation."
  fi
}

ensure_melos_shim() {
  local shim_dir="$HOME/.local/bin"
  mkdir -p "$shim_dir"

  if ! command_exists melos; then
    print_warning "Melos is not available; skipping melos shim creation."
    return
  fi

  local melos_path
  melos_path="$(command -v melos)"
  if [[ -x "$melos_path" ]]; then
    ln -snf "$melos_path" "$shim_dir/melos"
    append_to_path_if_dir "$shim_dir"
    print_step "Created/updated Melos shim in: $shim_dir"
    print_step "If needed, add shims to your shell profile: export PATH=\"$shim_dir:\$PATH\""
  fi
}

install_flutter_if_missing() {
  if command_exists flutter; then
    return
  fi

  ensure_cmd git "Git is required to install Flutter automatically."

  print_step "Flutter not found. Installing Flutter ($FLUTTER_CHANNEL) to: $FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"

  if [[ -d "$FLUTTER_HOME/.git" ]]; then
    print_step "Existing Flutter git checkout detected. Updating channel: $FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" fetch --all --tags
    git -C "$FLUTTER_HOME" checkout "$FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" pull --ff-only
  else
    rm -rf "$FLUTTER_HOME"
    git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" "$FLUTTER_HOME"
  fi

  append_to_path_if_dir "$FLUTTER_HOME/bin"
  persist_shell_path_hint "$FLUTTER_HOME/bin"
  ensure_flutter_shims "$FLUTTER_HOME/bin"

  ensure_cmd flutter "Flutter installation failed."
  print_success "Flutter installed successfully"
}

# Setup Flutter environment
setup_flutter_environment() {
    print_step "Setting up Flutter environment..."

    if command_exists flutter; then
        print_step "Enabling Flutter web support..."
        flutter config --enable-web || print_warning "Could not enable web support"
        print_success "Flutter web support configured"
    else
        print_error "Flutter is not installed. This should not happen after install_flutter_if_missing."
        return 1
    fi

    echo ""
}

# Bootstrap dependencies
bootstrap_dependencies() {
    print_step "Bootstrapping monorepo dependencies..."

    cd "$ROOT_DIR"

    if command_exists melos; then
        melos bootstrap
        print_success "Dependencies bootstrapped successfully"
    else
        print_error "Melos is not available. Cannot bootstrap dependencies."
        return 1
    fi

    echo ""
}

# Setup Git hooks (if any exist)
setup_git_hooks() {
    print_step "Checking for Git hooks..."

    if [ -d "$ROOT_DIR/.git/hooks" ]; then
        print_success "Git hooks directory exists"
        # Future: Add pre-commit hooks setup here
    else
        print_warning "Not a Git repository or hooks directory not found"
    fi

    echo ""
}

# Show next steps
show_next_steps() {
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║         Development Environment Ready!                ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    print_success "Your development environment is set up!"
    echo ""
    echo "Next steps:"
    echo "  1. Run tests:    melos test"
    echo "  2. Run scoped tests: melos exec --scope=agent_core -- dart test"
    echo "  3. Run analysis: melos analyze"
    echo "  4. Format code:  melos format"
    echo "  5. Build web:    cd apps/mobile_chat_app && flutter run -d chrome"
    echo "  6. Full build:   ./build.sh"
    echo ""
    echo "Environment notes:"
    echo "  - This script creates ~/.local/bin/flutter, ~/.local/bin/dart, and ~/.local/bin/melos shims."
    echo "  - If commands are missing in new shells, add: export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "  - UI integration tests require a runnable target (e.g. Chrome/Android/iOS)."
    echo ""
    echo "For more information, see:"
    echo "  - README.md"
    echo "  - BUILD.md"
    echo ""
}

# Parse command-line arguments
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
      [[ $# -gt 0 ]] || { print_error "--flutter-home requires a path argument."; exit 1; }
      FLUTTER_HOME="$1"
      ;;
    --channel)
      shift
      [[ $# -gt 0 ]] || { print_error "--channel requires a value."; exit 1; }
      FLUTTER_CHANNEL="$1"
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      print_error "Unknown option: $1. Use --help to see available options."
      exit 1
      ;;
  esac
  shift
done

# Main execution
main() {
    show_banner

    print_step "Repository root: $ROOT_DIR"

    # Ensure basic tools are available
    ensure_cmd git "Please install Git first."
    ensure_cmd bash "Please use a shell environment with bash available."

    # Install Flutter if missing
    install_flutter_if_missing

    # Determine the active Flutter bin directory for PATH and shims
    flutter_bin_dir=""
    if [[ -x "$FLUTTER_HOME/bin/flutter" ]]; then
        flutter_bin_dir="$FLUTTER_HOME/bin"
    elif command -v flutter >/dev/null 2>&1; then
        flutter_bin_dir="$(cd "$(dirname "$(command -v flutter)")" && pwd)"
    fi

    if [[ -n "${flutter_bin_dir:-}" ]]; then
        append_to_path_if_dir "$flutter_bin_dir"
        ensure_flutter_shims "$flutter_bin_dir"
    else
        print_warning "Flutter installation not found in FLUTTER_HOME or PATH; skipping shim creation."
    fi

    # Verify Flutter and Dart are available
    ensure_cmd flutter "Install Flutter SDK >= 3.x and ensure it is in PATH."
    ensure_cmd dart "Dart is bundled with Flutter; ensure Flutter bin is in PATH."

    # Check and install Melos
    if command_exists melos; then
        print_success "Melos already installed: $(melos --version 2>&1 || echo 'unknown version')"
        ensure_melos_shim
    else
        print_step "Melos not found in PATH. Installing via: dart pub global activate melos"
        dart pub global activate melos
        append_to_path_if_dir "$HOME/.pub-cache/bin"
        ensure_cmd melos "Run 'dart pub global activate melos' and add \"$HOME/.pub-cache/bin\" to PATH."
        ensure_melos_shim
        print_success "Melos installed successfully"
    fi

    # Setup Flutter environment
    setup_flutter_environment

    # Run Flutter doctor if requested
    if [[ "$RUN_DOCTOR" -eq 1 ]]; then
        print_step "Running flutter doctor"
        flutter doctor -v || print_warning "flutter doctor reported issues; continuing."
        echo ""
    fi

    # Bootstrap dependencies if requested
    if [[ "$RUN_BOOTSTRAP" -eq 1 ]]; then
        bootstrap_dependencies
    fi

    # Setup Git hooks
    setup_git_hooks

    # Show completion message
    show_next_steps
    print_success "Initialization completed successfully."
}

# Run main function
main "$@"
