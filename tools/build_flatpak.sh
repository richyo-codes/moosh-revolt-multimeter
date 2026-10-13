#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
MANIFEST="$ROOT_DIR/flatpak/ca.richyoung.mooshrevolt.yml"
BUILD_DIR="$ROOT_DIR/build/flatpak"
REPO_DIR="$ROOT_DIR/build/flatpak-repo"
BUNDLE_PATH="$ROOT_DIR/build/ca.richyoung.mooshrevolt.flatpak"
APP_ID="ca.richyoung.mooshrevolt"

if ! command -v flatpak-builder >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    echo "Install Flatpak tooling with: sudo dnf install -y flatpak flatpak-builder" >&2
  else
    echo "Install Flatpak tooling with: sudo apt-get install flatpak flatpak-builder" >&2
  fi
  exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak not found in PATH." >&2
  exit 1
fi

if [[ "${1:-}" != "--skip-build" ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found in PATH." >&2
    exit 1
  fi
  flutter build linux --release
fi

if [[ ! -x "$ROOT_DIR/build/linux/x64/release/bundle/mooshrevolt" ]]; then
  echo "Expected Flutter bundle missing: build/linux/x64/release/bundle/mooshrevolt" >&2
  exit 1
fi

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive flathub org.freedesktop.Sdk/x86_64/25.08 org.freedesktop.Platform/x86_64/25.08

BUILDER_ARGS=(--disable-rofiles-fuse --force-clean)
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  if flatpak-builder --help 2>/dev/null | grep -q -- '--disable-sandbox'; then
    BUILDER_ARGS+=(--disable-sandbox)
  fi
fi

flatpak-builder "${BUILDER_ARGS[@]}" --repo="$REPO_DIR" "$BUILD_DIR" "$MANIFEST"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_PATH" "$APP_ID"

echo "Flatpak bundle created: $BUNDLE_PATH"
echo "Install with: flatpak install --user --reinstall $BUNDLE_PATH"
