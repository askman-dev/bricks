# Developer Tools

This directory contains developer tooling scripts for the Bricks monorepo.

## Available tools

### Shell Scripts

- **`common.sh`** – Shared library with reusable validation functions
  - Color output helpers (`print_step`, `print_success`, `print_error`, `print_warning`)
  - Command existence checker (`command_exists`)
  - Command guards (`ensure_cmd`, `ensure_or_install_cmd`)
  - Legacy Flutter prerequisite validation (`check_prerequisites`) retained for compatibility
  - Used by `init_dev_env.sh`

- **`init_dev_env.sh`** – Initialize development environment
  - Canonical setup entrypoint for both local development and Codex/container runs
  - Validates required CLI tools (`git`, `curl`, `jq`, `node`, `npm`)
  - Installs backend dependencies with `npm ci`
  - Installs React frontend dependencies with `npm ci`
  - Provides guidance for next steps
  - Usage: `./tools/init_dev_env.sh`

## Planned tools

- `generate_fixtures.dart` – generate sample workspace/project fixtures
- `check_pubspecs.dart` – validate pubspec.yaml consistency across packages
- `changelog.dart` – generate changelog from git history
