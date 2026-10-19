#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_ID="ca.richyoung.mooshrevolt"
GTK_VARIANT=gtk3
OUT_DIR="$ROOT_DIR/build"
HOST_BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
while (( $# )); do
  case "$1" in
    --gtk|--out-dir|--bundle-dir)
      if (( $# < 2 )); then echo "$1 requires a value" >&2; exit 2; fi
      case "$1" in
        --gtk) GTK_VARIANT="$2" ;;
        --out-dir) OUT_DIR="$2" ;;
        --bundle-dir) HOST_BUNDLE_DIR="$2" ;;
      esac
      shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$GTK_VARIANT" in
  gtk3) RUNTIME=org.freedesktop; RUNTIME_VERSION=25.08; BRANCH=master; SUFFIX="" ;;
  gtk4) RUNTIME=org.gnome; RUNTIME_VERSION=51; BRANCH=gtk4; SUFFIX=.gtk4 ;;
  *) echo "Expected gtk3 or gtk4" >&2; exit 2 ;;
esac
MANIFEST="$ROOT_DIR/flatpak/$APP_ID.yml"
if [[ "$GTK_VARIANT" == gtk4 ]]; then MANIFEST="$ROOT_DIR/flatpak/$APP_ID.gtk4.yml"; fi
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
HOST_BUNDLE_DIR="$(cd "$HOST_BUNDLE_DIR" && pwd)"
BUNDLE_PATH="$OUT_DIR/$APP_ID$SUFFIX.flatpak"
CONTAINER_ROOT="/src"
CONTAINER_MANIFEST="$CONTAINER_ROOT/flatpak/$APP_ID$SUFFIX.yml"
CONTAINER_BUILD_DIR="/output/flatpak"
CONTAINER_REPO_DIR="/output/flatpak-repo"
CONTAINER_BUNDLE_PATH="/output/$APP_ID$SUFFIX.flatpak"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Flatpak manifest not found: $MANIFEST" >&2
  exit 1
fi

if command -v podman >/dev/null 2>&1; then
  ENGINE="podman"
elif command -v docker >/dev/null 2>&1; then
  ENGINE="docker"
else
  echo "Neither podman nor docker was found in PATH." >&2
  exit 1
fi

IMAGE="ghcr.io/flathub-infra/flatpak-builder-lint:latest"

mkdir -p "$ROOT_DIR/build"

if [[ ! -f "$HOST_BUNDLE_DIR/mooshrevolt" ]]; then
  echo "Missing $HOST_BUNDLE_DIR/mooshrevolt. Run: flutter build linux --release" >&2
  exit 1
fi

MOUNT_SPEC="$ROOT_DIR:/src:Z"
TTY_ARGS=(-i)
if [[ -t 1 ]]; then
  TTY_ARGS+=(-t)
fi

"$ENGINE" run --rm "${TTY_ARGS[@]}" \
  --privileged \
  --device /dev/fuse \
  --security-opt label=disable \
  --entrypoint /bin/bash \
  -v "$MOUNT_SPEC" \
  -v "$HOST_BUNDLE_DIR:/bundle:ro,Z" \
  -v "$OUT_DIR:/output:Z" \
  -w /src \
  "$IMAGE" \
  -lc "
    set -euo pipefail
    flatpak-builder --version
    dbus-uuidgen --ensure=/etc/machine-id
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak remotes || true
    flatpak --system install -y --noninteractive --no-related flathub \
      $RUNTIME.Sdk/x86_64/$RUNTIME_VERSION \
      $RUNTIME.Platform/x86_64/$RUNTIME_VERSION

    sed -E 's@path: ../build/linux(-gtk4)?/x64/release/bundle@path: /bundle@; s@path: \\.\$@path: /src/flatpak@; s@path: ../linux/assets/icons@path: /src/linux/assets/icons@; s@path: ../LICENSE@path: /src/LICENSE@' \
      '$CONTAINER_MANIFEST' > /tmp/moosh-manifest.yml

    flatpak-builder --disable-rofiles-fuse --force-clean --state-dir=/output/flatpak-state --repo='$CONTAINER_REPO_DIR' '$CONTAINER_BUILD_DIR' /tmp/moosh-manifest.yml
    if [[ '$GTK_VARIANT' == gtk4 ]]; then
      flatpak build --runtime '$CONTAINER_BUILD_DIR' sh -c '
        set -e
        export LD_LIBRARY_PATH=/app/bin/lib
        for target in /app/bin/mooshrevolt /app/bin/lib/*.so*; do ldd "\$target"; done
      ' > /tmp/moosh-libraries.txt 2>&1
      if grep -Eq '=> not found|version .* not found|libgtk-3.so' /tmp/moosh-libraries.txt; then
        cat /tmp/moosh-libraries.txt >&2
        exit 1
      fi
    fi
    flatpak build-bundle '$CONTAINER_REPO_DIR' '$CONTAINER_BUNDLE_PATH' '$APP_ID' '$BRANCH'
  "

echo "Flatpak bundle created: $BUNDLE_PATH"
echo "Install with: flatpak install --user --reinstall $BUNDLE_PATH"
