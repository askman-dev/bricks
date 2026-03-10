#!/usr/bin/env bash

# Bricks Build Script
# This script provides a complete build pipeline for the Bricks monorepo

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/tools/common.sh"

# Step 1: Check prerequisites (using common library)
_check_prerequisites_build() {
    if ! check_prerequisites; then
        exit 1
    fi
}

# Step 2: Clean previous builds
clean_build() {
    print_step "Cleaning previous builds..."

    if command_exists melos; then
        melos clean || true
    fi

    # Clean Flutter build artifacts
    rm -rf apps/mobile_chat_app/build
    rm -rf apps/mobile_chat_app/.dart_tool

    # Clean package build artifacts
    find packages -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
    find packages -type d -name ".dart_tool" -exec rm -rf {} + 2>/dev/null || true

    print_success "Clean completed"
    echo ""
}

# Step 3: Bootstrap dependencies
bootstrap() {
    print_step "Bootstrapping dependencies with melos..."

    melos bootstrap

    print_success "Bootstrap completed"
    echo ""
}

# Step 4: Analyze code
analyze() {
    print_step "Running static analysis..."

    melos analyze

    print_success "Analysis completed"
    echo ""
}

# Step 5: Format check
format_check() {
    print_step "Checking code formatting..."

    # Check if code is formatted
    dart format --output=none --set-exit-if-changed . || {
        print_warning "Code formatting issues found"
        echo "Run 'melos format' to fix formatting"
        return 1
    }

    print_success "Format check completed"
    echo ""
}

# Step 6: Run tests
run_tests() {
    print_step "Running tests..."

    melos test

    print_success "Tests completed"
    echo ""
}

# Step 7: Build web app
build_web() {
    print_step "Building web application..."

    cd apps/mobile_chat_app
    flutter build web --release
    cd ../..

    print_success "Web build completed"
    echo ""
}

# Step 8: Build mobile app (optional)
build_mobile() {
    local platform=$1

    print_step "Building mobile application for $platform..."

    cd apps/mobile_chat_app

    case $platform in
        android)
            flutter build apk --release
            print_success "Android APK built: apps/mobile_chat_app/build/app/outputs/flutter-apk/app-release.apk"
            ;;
        ios)
            flutter build ios --release
            print_success "iOS build completed"
            ;;
        *)
            print_error "Unknown platform: $platform"
            cd ../..
            return 1
            ;;
    esac

    cd ../..
    echo ""
}

# Main build pipeline
main() {
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║         Bricks Monorepo Build Script                 ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""

    local start_time=$(date +%s)

    # Parse arguments
    local skip_clean=false
    local skip_tests=false
    local skip_analyze=false
    local skip_format=false
    local build_target="web"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-clean)
                skip_clean=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-analyze)
                skip_analyze=true
                shift
                ;;
            --skip-format)
                skip_format=true
                shift
                ;;
            --target)
                build_target="$2"
                shift 2
                ;;
            --help|-h)
                echo "Usage: ./build.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-clean      Skip cleaning previous builds"
                echo "  --skip-tests      Skip running tests"
                echo "  --skip-analyze    Skip static analysis"
                echo "  --skip-format     Skip format checking"
                echo "  --target TARGET   Build target: web, android, ios (default: web)"
                echo "  --help, -h        Show this help message"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Run build pipeline
    _check_prerequisites_build

    if [ "$skip_clean" = false ]; then
        clean_build
    fi

    bootstrap

    if [ "$skip_analyze" = false ]; then
        analyze || {
            print_error "Analysis failed. Fix the issues and try again."
            exit 1
        }
    fi

    if [ "$skip_format" = false ]; then
        format_check || {
            print_warning "Format check failed, but continuing..."
        }
    fi

    if [ "$skip_tests" = false ]; then
        run_tests || {
            print_error "Tests failed. Fix the issues and try again."
            exit 1
        }
    fi

    case $build_target in
        web)
            build_web
            ;;
        android|ios)
            build_mobile "$build_target"
            ;;
        *)
            print_error "Invalid build target: $build_target"
            exit 1
            ;;
    esac

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║              Build Completed Successfully!            ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    print_success "Total build time: ${duration}s"
    echo ""

    case $build_target in
        web)
            echo "Web build output: apps/mobile_chat_app/build/web"
            ;;
        android)
            echo "Android APK: apps/mobile_chat_app/build/app/outputs/flutter-apk/app-release.apk"
            ;;
        ios)
            echo "iOS build: apps/mobile_chat_app/build/ios"
            ;;
    esac
}

# Run main function
main "$@"
