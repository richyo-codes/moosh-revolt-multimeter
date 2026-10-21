#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
MANIFEST="$ROOT_DIR/flatpak/ca.richyoung.mooshrevolt.yml"
APP_ID="ca.richyoung.mooshrevolt"
OUT_DIR="$ROOT_DIR/build"
SKIP_BUILD=false

usage() {
  cat <<'EOF'
Usage: ./tools/build_flatpak.sh [--skip-build] [--out-dir PATH]

  --skip-build    Package the existing Flutter release bundle.
  --out-dir PATH Store builder files, cache, repository, and bundle under PATH
                 (default: build/ in the project).
EOF
}

while (( $# )); do
  case "$1" in
    --skip-build) SKIP_BUILD=true; shift ;;
    --out-dir)
      if (( $# < 2 )) || [[ -z "$2" || "$2" == --* ]]; then
        echo "--out-dir requires a path" >&2; exit 2
      fi
      OUT_DIR="$2"; shift 2 ;;
    --out-dir=*)
      OUT_DIR="${1#*=}"
      if [[ -z "$OUT_DIR" ]]; then echo "--out-dir requires a path" >&2; exit 2; fi
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd -P)"
BUILD_DIR="$OUT_DIR/flatpak"
STATE_DIR="$OUT_DIR/flatpak-state"
REPO_DIR="$OUT_DIR/flatpak-repo"
BUNDLE_PATH="$OUT_DIR/$APP_ID.flatpak"

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

if [[ "$SKIP_BUILD" != true ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "flutter not found in PATH." >&2
    exit 1
  fi
  (cd "$ROOT_DIR" && flutter build linux --release)
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

flatpak-builder "${BUILDER_ARGS[@]}" --state-dir="$STATE_DIR" --repo="$REPO_DIR" "$BUILD_DIR" "$MANIFEST"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_PATH" "$APP_ID"

echo "Flatpak bundle created: $BUNDLE_PATH"
echo "Install with: flatpak install --user --reinstall $BUNDLE_PATH"
