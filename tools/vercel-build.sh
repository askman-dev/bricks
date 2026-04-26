#!/usr/bin/env bash
set -euo pipefail

INSTALL_ONLY="${1:-}"

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    echo "Flutter already available: $(flutter --version | head -n 1)"
    return 0
  fi

  local flutter_version="${FLUTTER_VERSION:-stable}"
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

install_docs_site() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "Error: 'npm' is required to install docs site dependencies but was not found in PATH." >&2
    exit 1
  fi
  echo "Installing docs site dependencies..."
  (
    cd apps/docs_site
    npm ci
  )
}

build_docs_site() {
  echo "Building docs site..."
  (
    cd apps/docs_site
    npm run build
  )

  echo "Copying docs site into Flutter web output..."
  rm -rf apps/mobile_chat_app/build/web/docs
  mkdir -p apps/mobile_chat_app/build/web/docs
  cp -R apps/docs_site/build/. apps/mobile_chat_app/build/web/docs/
}

ensure_flutter
flutter config --enable-web >/dev/null

if [ "${INSTALL_ONLY}" = "--install-only" ]; then
  echo "Running install-only setup..."
  flutter --version
  (
    cd apps/mobile_chat_app
    flutter pub get
  )
  flutter precache --web 2>&1 || echo "Warning: flutter precache --web failed; build may be slower." >&2
  install_docs_site
  echo "Install-only step finished."
  exit 0
fi

flutter --version
(
  cd apps/mobile_chat_app
  flutter pub get
  flutter build web --release
)

# Useful for local runs where --install-only was not executed first.
if [ ! -d apps/docs_site/node_modules ]; then
  install_docs_site
fi

build_docs_site
