# Developer Tools

This directory contains developer tooling scripts for the Bricks monorepo.

## Available tools

### Shell Scripts

- **`../init-env-for-codex.sh`** – Fast setup script for Codex/container environments
  - Installs Flutter (if missing) into `$HOME/.local/flutter` by default
  - Installs Melos via `dart pub global activate melos`
  - Adds Flutter and pub-cache bins to PATH for the current shell session
  - Usage: `./init-env-for-codex.sh`

- **`common.sh`** – Shared library with reusable validation functions
  - Color output helpers (`print_step`, `print_success`, `print_error`, `print_warning`)
  - Command existence checker (`command_exists`)
  - Prerequisites validation (`check_prerequisites`)
  - Used by both `build.sh` and `init_dev_env.sh`

- **`init_dev_env.sh`** – Initialize development environment
  - Checks prerequisites (Flutter, Dart, Melos)
  - Sets up Flutter web support
  - Bootstraps monorepo dependencies with Melos
  - Provides guidance for next steps
  - Usage: `./tools/init_dev_env.sh [--skip-bootstrap] [--skip-flutter-setup]`

## Planned tools

- `generate_fixtures.dart` – generate sample workspace/project fixtures
- `check_pubspecs.dart` – validate pubspec.yaml consistency across packages
- `changelog.dart` – generate changelog from git history
