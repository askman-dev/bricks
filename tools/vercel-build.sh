#!/usr/bin/env bash
set -euo pipefail

INSTALL_ONLY="${1:-}"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    echo "Flutter already available: $(flutter --version | head -n 1)"
    return 0
  fi

  local flutter_version="${FLUTTER_VERSION:-3.24.0}"
  local flutter_root="${FLUTTER_HOME:-${HOME}/.local/flutter}"

  if [ ! -d "${flutter_root}" ]; then
    echo "Installing Flutter SDK version ${flutter_version} to ${flutter_root}..."
    if ! command -v git >/dev/null 2>&1; then
      echo "Error: 'git' is required to install the Flutter SDK but was not found in PATH." >&2
      exit 1
    fi
    mkdir -p "$(dirname "${flutter_root}")"
    git clone https://github.com/flutter/flutter.git --depth 1 -b "${flutter_version}" "${flutter_root}"
  fi

  export PATH="${flutter_root}/bin:${PATH}"
  echo "Using Flutter from ${flutter_root}"
}

ensure_flutter
flutter config --enable-web >/dev/null

if [ "${INSTALL_ONLY}" = "--install-only" ]; then
  echo "Running install-only setup (pub get and web precache)..."
  flutter --version
  (
    cd apps/mobile_chat_app
    flutter pub get
  )
  flutter precache --web 2>&1 || echo "Warning: flutter precache --web failed; build may be slower." >&2
  echo "Install-only step finished."
  exit 0
fi

flutter --version
(
  cd apps/mobile_chat_app
  flutter pub get
  flutter build web --release
)
