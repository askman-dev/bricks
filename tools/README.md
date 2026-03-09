# Developer Tools

This directory contains developer tooling scripts for the Bricks monorepo.

## Available tools

- `init_dev_env.sh` – initialize local environment (auto-install Flutter when missing, check Dart, install Melos if needed, and run `melos bootstrap`)

```bash
# from repo root
bash tools/init_dev_env.sh

# optional flags
bash tools/init_dev_env.sh --no-doctor
bash tools/init_dev_env.sh --no-bootstrap
bash tools/init_dev_env.sh --flutter-home "$HOME/.local/flutter"
bash tools/init_dev_env.sh --channel stable
```

## Planned tools

- `generate_fixtures.dart` – generate sample workspace/project fixtures
- `check_pubspecs.dart` – validate pubspec.yaml consistency across packages
- `changelog.dart` – generate changelog from git history
