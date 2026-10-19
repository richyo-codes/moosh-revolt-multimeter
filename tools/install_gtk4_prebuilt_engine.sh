#!/usr/bin/env bash
set -euo pipefail

flutter_root="${1:?Usage: $0 /path/to/flutter-sdk}"
engine_version="${FLUTTER_PREBUILT_ENGINE_VERSION:?Set FLUTTER_PREBUILT_ENGINE_VERSION}"
storage_base_url="${FLUTTER_ENGINE_STORAGE_BASE_URL:?Set FLUTTER_ENGINE_STORAGE_BASE_URL}"
engine_root="$flutter_root/bin/cache/artifacts/engine"
archive_base="$storage_base_url/flutter_infra_release/flutter/$engine_version"

verify_engine_bundle() {
  local destination="$1"
  local build_mode="$2"
  local required_file

  # Keep this in step with the regular Linux engine archive contract. GTK4 is
  # an additional runner library, rather than a GTK3 replacement.
  for required_file in \
    LICENSE.flutter_gtk.md \
    flutter_linux/flutter_linux.h \
    gen_snapshot \
    libflutter_linux_gtk.so \
    libflutter_linux_gtk4.so; do
    if [[ ! -f "$destination/$required_file" ]]; then
      echo "Published $build_mode Linux engine is missing $required_file" >&2
      exit 1
    fi
  done

  if [[ ! -x "$destination/gen_snapshot" ]]; then
    echo "Published $build_mode Linux engine has a non-executable gen_snapshot" >&2
    exit 1
  fi

  local dart_version snapshot_version
  dart_version="$("$flutter_root/bin/cache/dart-sdk/bin/dart" --version 2>&1 |
    sed -nE 's/^Dart (SDK|VM) version: ([^ ]+).*/\2/p')"
  snapshot_version="$("$destination/gen_snapshot" --version 2>&1 |
    sed -nE 's/^Dart (SDK|VM) version: ([^ ]+).*/\2/p')"
  if [[ -z "$dart_version" || "$dart_version" != "$snapshot_version" ]]; then
    echo "Published $build_mode gen_snapshot ($snapshot_version) does not match the Dart SDK ($dart_version)." >&2
    echo "Republish the Dart SDK and engine archives from the same Dart revision." >&2
    exit 1
  fi

  if ! readelf -d "$destination/libflutter_linux_gtk.so" |
    grep -q 'Shared library: \[libgtk-3.so'; then
    echo "Published $build_mode GTK3 engine is not linked to GTK3" >&2
    exit 1
  fi
  if ! readelf -d "$destination/libflutter_linux_gtk4.so" |
    grep -q 'Shared library: \[libgtk-4.so'; then
    echo "Published $build_mode GTK4 engine is not linked to GTK4" >&2
    exit 1
  fi
}

for cache_mode in linux-x64 linux-x64-profile linux-x64-release; do
  archive_mode="$cache_mode"
  if [[ "$cache_mode" == linux-x64 ]]; then
    archive_mode=linux-x64-debug
  fi
  destination="$engine_root/$cache_mode"
  archive_url="$archive_base/$archive_mode/linux-x64-flutter-gtk.zip"
  archive_file="$(mktemp "${TMPDIR:-/tmp}/moosh-gtk4-engine.XXXXXX.zip")"
  trap 'rm -f "$archive_file"' EXIT
  mkdir -p "$destination"
  curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
    "$archive_url" -o "$archive_file"
  unzip -tq "$archive_file"
  unzip -q -o "$archive_file" -d "$destination"
  rm -f "$archive_file"
  trap - EXIT
  verify_engine_bundle "$destination" "$archive_mode"
done
