#!/usr/bin/env bash
set -euo pipefail

INSTALL_ONLY="${1:-}"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    echo "Flutter already available: $(flutter --version | head -n 1)"
    return 0
  fi

  local flutter_root="${HOME}/flutter"
  if [ ! -d "${flutter_root}" ]; then
    echo "Installing Flutter SDK to ${flutter_root}..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${flutter_root}"
  fi

  export PATH="${flutter_root}/bin:${PATH}"
  echo "Using Flutter from ${flutter_root}"
}

ensure_flutter
flutter config --enable-web >/dev/null

if [ "${INSTALL_ONLY}" = "--install-only" ]; then
  echo "Install-only step finished."
  exit 0
fi

flutter --version
(
  cd apps/mobile_chat_app
  flutter pub get
  flutter build web --release
)
