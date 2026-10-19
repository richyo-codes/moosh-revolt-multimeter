#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
variant="${1:-gtk3}"
action="${2:-run}"
if (( $# > 0 )); then shift; fi
if (( $# > 0 )); then shift; fi
case "$variant" in
  gtk3|gtk4) ;;
  *) echo "Usage: $0 {gtk3|gtk4} {run|build} [Flutter arguments...]" >&2; exit 2 ;;
esac
case "$action" in
  run) flutter_args=(run -d linux) ;;
  build) flutter_args=(build linux) ;;
  *) echo "Expected run or build, got: $action" >&2; exit 2 ;;
esac

cd "$project_dir"
flutter_bin="${FLUTTER_BIN:-flutter}"
if ! command -v "$flutter_bin" >/dev/null 2>&1; then
  echo "Flutter executable not found: $flutter_bin" >&2
  exit 1
fi

if [[ "$variant" == gtk4 ]]; then
  if [[ -z "${LOCAL_ENGINE_SRC:-}" && -z "${FLUTTER_PREBUILT_ENGINE_VERSION:-}" ]]; then
    echo "GTK4 requires LOCAL_ENGINE_SRC or FLUTTER_PREBUILT_ENGINE_VERSION." >&2
    echo "Use the matching GTK4-enabled Flutter SDK; see docs/linux-gtk.md." >&2
    exit 1
  fi
  if [[ -z "${LOCAL_ENGINE_SRC:-}" && -z "${FLUTTER_ENGINE_STORAGE_BASE_URL:-}" ]]; then
    echo "Set FLUTTER_ENGINE_STORAGE_BASE_URL for the prebuilt GTK4 engine." >&2
    exit 1
  fi
  flutter_args+=(--linux-gtk=gtk4)
fi

if [[ -n "${LOCAL_ENGINE_SRC:-}" ]]; then
  engine="${LOCAL_ENGINE:-host_debug_unopt}"
  host_engine="${LOCAL_ENGINE_HOST:-$engine}"
  engine_library=libflutter_linux_gtk.so
  if [[ "$variant" == gtk4 ]]; then
    engine_library=libflutter_linux_gtk4.so
  fi
  if [[ ! -f "$LOCAL_ENGINE_SRC/out/$engine/$engine_library" ]]; then
    echo "Missing local engine: $LOCAL_ENGINE_SRC/out/$engine/$engine_library" >&2
    exit 1
  fi
  flutter_args+=("--local-engine=$engine"
    "--local-engine-host=$host_engine"
    "--local-engine-src-path=$LOCAL_ENGINE_SRC")
fi

# One-shot selection: do not change the developer's persistent GTK preference.
export FLUTTER_LINUX_GTK="$variant"
exec "$flutter_bin" "${flutter_args[@]}" "$@"
