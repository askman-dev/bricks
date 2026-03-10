# Building Bricks - Step-by-Step Guide

This guide provides comprehensive instructions for building the Bricks monorepo project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Build Steps](#detailed-build-steps)
- [Build Script Usage](#build-script-usage)
- [Troubleshooting](#troubleshooting)
- [CI/CD Pipeline](#cicd-pipeline)

---

## Prerequisites

### Required Tools

Before building Bricks, ensure you have the following tools installed:

1. **Flutter SDK** (≥ 3.0.0)
   - Download from: https://docs.flutter.dev/get-started/install
   - Verify installation: `flutter --version`

2. **Dart SDK** (≥ 3.0.0)
   - Usually comes with Flutter
   - Verify installation: `dart --version`

3. **Melos** (monorepo management)
   - Install: `dart pub global activate melos`
   - Verify installation: `melos --version`

### System Requirements

- **macOS**: Required for iOS builds
- **Linux/macOS/Windows**: Supported for web and Android builds
- **Android Studio**: Required for Android builds (with Android SDK)
- **Xcode**: Required for iOS builds (macOS only)

### Verifying Prerequisites

Run the following commands to verify your setup:

```bash
flutter doctor -v
dart --version
melos --version
```

---

## Quick Start

For a quick build using the automated script:

```bash
# Make the script executable (first time only)
chmod +x build.sh

# Run the build script
./build.sh
```

This will:
1. Check prerequisites
2. Clean previous builds
3. Bootstrap dependencies
4. Run static analysis
5. Check code formatting
6. Run tests
7. Build the web application

---

## Detailed Build Steps

Follow these steps to manually build the project:

### Step 1: Clone the Repository

```bash
git clone https://github.com/askman-dev/bricks.git
cd bricks
```

### Step 2: Bootstrap Dependencies

Bootstrap all packages in the monorepo:

```bash
melos bootstrap
```

This command will:
- Run `flutter pub get` on all packages
- Link local package dependencies
- Generate `pubspec_overrides.yaml` files

**Expected Output:**
```
Running "flutter pub get" in workspace packages...
  ✓ agent_core
  ✓ agent_sdk_contract
  ✓ bricks_ai_core
  ✓ chat_domain
  ✓ design_system
  ✓ platform_bridge
  ✓ project_system
  ✓ test_harness
  ✓ workspace_fs
  ✓ mobile_chat_app

SUCCESS
```

### Step 3: Static Analysis

Run Dart analyzer on all packages:

```bash
melos analyze
```

This checks for:
- Type errors
- Unused imports
- Deprecated API usage
- Lint rule violations

**Expected Output:**
```
Analyzing packages...
No issues found!
```

**If errors are found:**
- Fix each error by editing the relevant files
- Re-run `melos analyze` to verify fixes

### Step 4: Code Formatting

Check code formatting:

```bash
dart format --output=none --set-exit-if-changed .
```

**If formatting issues exist:**

```bash
# Auto-format all code
melos format

# Or format specific files
dart format lib/
```

### Step 5: Run Tests

Run all tests in the monorepo:

```bash
melos test
```

This runs:
- Unit tests
- Widget tests
- Integration tests

**Expected Output:**
```
Running "dart test" in workspace packages...
  ✓ agent_core (15 tests passed)
  ✓ agent_sdk_contract (8 tests passed)
  ✓ workspace_fs (12 tests passed)
  ...

All tests passed!
```

**If tests fail:**
- Review the test output to identify failing tests
- Fix the issues in the relevant source files
- Re-run tests to verify fixes

### Step 6: Build the Application

#### Build for Web (Production)

```bash
cd apps/mobile_chat_app
flutter build web --release
```

**Output location:** `apps/mobile_chat_app/build/web`

**Optional flags:**
```bash
# Custom base href for deployment
flutter build web --base-href "/your-path/" --release

# With source maps for debugging
flutter build web --release --source-maps
```

#### Build for Android

```bash
cd apps/mobile_chat_app

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

**Output location:**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

#### Build for iOS

```bash
cd apps/mobile_chat_app

# Build iOS app
flutter build ios --release
```

**Note:** Requires macOS and Xcode. For simulator builds, omit `--release`.

#### Development Builds

For development/debugging, run:

```bash
cd apps/mobile_chat_app

# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Hot reload is enabled in debug mode
# Press 'r' to hot reload, 'R' to hot restart
```

### Step 7: Verify Build

Check the build output:

```bash
# For web builds
ls -lh apps/mobile_chat_app/build/web/

# For Android builds
ls -lh apps/mobile_chat_app/build/app/outputs/flutter-apk/

# Test web build locally
cd apps/mobile_chat_app/build/web
python3 -m http.server 8000
# Visit http://localhost:8000
```

---

## Build Script Usage

The `build.sh` script automates the entire build pipeline.

### Basic Usage

```bash
./build.sh
```

### Options

```bash
./build.sh [OPTIONS]

Options:
  --skip-clean      Skip cleaning previous builds
  --skip-tests      Skip running tests
  --skip-analyze    Skip static analysis
  --skip-format     Skip format checking
  --target TARGET   Build target: web, android, ios (default: web)
  --help, -h        Show help message
```

### Examples

```bash
# Build for Android without running tests
./build.sh --skip-tests --target android

# Quick rebuild (skip clean)
./build.sh --skip-clean

# Build iOS app with all checks
./build.sh --target ios

# Fast iteration (skip all checks)
./build.sh --skip-clean --skip-tests --skip-analyze --skip-format
```

---

## Troubleshooting

### Common Issues

#### 1. "melos: command not found"

**Solution:**
```bash
dart pub global activate melos

# Add to PATH (if needed)
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

#### 2. "Package dependencies are not met"

**Solution:**
```bash
# Clean and re-bootstrap
melos clean
melos bootstrap
```

#### 3. "Analysis errors found"

**Solution:**
- Review error messages from `melos analyze`
- Fix type errors, import issues, and lint violations
- Common fixes:
  - Add missing imports
  - Fix type mismatches
  - Remove unused variables/imports
  - Update deprecated API usage

#### 4. "Tests failing"

**Solution:**
```bash
# Run tests for specific package
cd packages/<package-name>
dart test

# Run specific test file
dart test test/specific_test.dart

# Run with verbose output
dart test --reporter=expanded
```

#### 5. "Flutter build failed"

**Solution:**
```bash
# Clean Flutter build cache
cd apps/mobile_chat_app
flutter clean
flutter pub get

# Verify Flutter installation
flutter doctor -v

# Try building again
flutter build web --release
```

#### 6. "Memory issues during build"

**Solution:**
```bash
# Increase available memory for Dart
export DART_VM_OPTIONS="--old_gen_heap_size=4096"

# Build with less concurrency
melos exec --concurrency=1 -- flutter pub get
```

### Getting Help

If you encounter issues not covered here:

1. Check the error message carefully
2. Search GitHub issues: https://github.com/askman-dev/bricks/issues
3. Run `flutter doctor -v` to diagnose environment issues
4. Enable verbose logging: `flutter build web --verbose`

---

## CI/CD Pipeline

### GitHub Actions Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/deploy_web.yaml`) that automatically builds and deploys the web app on push to `main`.

**Workflow steps:**
1. Checkout repository
2. Setup Flutter SDK
3. Install dependencies (`flutter pub get`)
4. Build web app (`flutter build web --release`)
5. Deploy to GitHub Pages

### Running CI Checks Locally

Before pushing, run the same checks that CI will run:

```bash
# Full CI check simulation
./build.sh

# Or manually:
melos bootstrap
melos analyze
melos test
cd apps/mobile_chat_app && flutter build web --release
```

### Setting Up CI for Your Fork

1. Fork the repository
2. Enable GitHub Actions in your fork
3. Enable GitHub Pages in repository settings
4. The workflow will automatically run on push to `main`

---

## Additional Commands

### Clean Everything

```bash
# Using melos
melos clean

# Manual cleanup
find . -type d -name "build" -exec rm -rf {} + 2>/dev/null
find . -type d -name ".dart_tool" -exec rm -rf {} + 2>/dev/null
find . -name "pubspec_overrides.yaml" -delete
```

### Update Dependencies

```bash
# Update all package dependencies
melos exec -- flutter pub upgrade

# Update specific package
cd packages/<package-name>
flutter pub upgrade
```

### Generate Documentation

```bash
# Generate API documentation for all packages
melos exec -- dart doc

# Documentation will be in <package>/doc/api/
```

### Run Specific Package Tests

```bash
# Run tests for a specific package
melos run test --scope=agent_core

# Or navigate to package
cd packages/agent_core
dart test
```

---

## Build Performance Tips

1. **Incremental builds**: Use `--skip-clean` for faster rebuilds
2. **Parallel execution**: Melos runs tasks in parallel automatically
3. **Selective builds**: Use `--scope` to build specific packages
4. **Cache**: Don't delete `.dart_tool` unless necessary
5. **Development builds**: Use debug mode for faster iteration

---

## Summary Checklist

Before considering a build complete:

- [ ] Prerequisites installed and verified
- [ ] Dependencies bootstrapped (`melos bootstrap`)
- [ ] Static analysis passes (`melos analyze`)
- [ ] Code formatting correct (`dart format`)
- [ ] All tests pass (`melos test`)
- [ ] Application builds successfully
- [ ] Build output verified and tested

---

**Last Updated:** 2026-03-09
**Maintainers:** Bricks Team
**Repository:** https://github.com/askman-dev/bricks
