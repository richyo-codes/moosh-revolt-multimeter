# GTK4 Linux builds

GTK3 remains the default. GTK4 uses the custom Flutter fork and its matching
prebuilt engine; both variants share application ID `ca.richyoung.mooshrevolt`
and request a 1280 x 720 startup window with native decorations.

## Build and run

Use a checkout of `https://github.com/richyo-codes/flutter.git`, branch
`3.48.0-gtk4.issue94804.20260925`, pinned to
`e95aed6a2a35bdcc2242d944e08267b78f9ea317`:

```sh
export FLUTTER_BIN=/path/to/flutter-fork/bin/flutter
export FLUTTER_PREBUILT_ENGINE_VERSION=e0462bb4b7f33fb7bf4c59ba2a73cfa1d0385ce1
export FLUTTER_ENGINE_STORAGE_BASE_URL=https://pub-79a02b1963fb4da6b5e4e4816e8b7146.r2.dev
FLUTTER_STORAGE_BASE_URL="$FLUTTER_ENGINE_STORAGE_BASE_URL" "$FLUTTER_BIN" --version
bash tools/install_gtk4_prebuilt_engine.sh /path/to/flutter-fork
bash tools/flutter_linux.sh gtk4 build --release
bash tools/flutter_linux.sh gtk4 run
```

For a locally compiled engine, set `LOCAL_ENGINE_SRC` to its `engine/src`
directory and `LOCAL_ENGINE`/`LOCAL_ENGINE_HOST` to matching build modes.
The default local configuration is `host_debug_unopt`.

GTK4 output is under `build/linux-gtk4/x64/release/bundle`. GTK3 continues to
use `build/linux/x64/release/bundle`. Generated Linux ephemeral files are shared;
do not build the two variants concurrently in one checkout.

## GTK4 Flatpak

Install `flatpak`, `flatpak-builder`, and `patchelf`, then install GNOME 51:

```sh
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//51 org.gnome.Sdk//51
bash tools/build_flatpak_gtk4.sh --bundle-dir build/linux-gtk4/x64/release/bundle
flatpak install --user build/linux-gtk4/flatpak-output/ca.richyoung.mooshrevolt.gtk4.flatpak
flatpak run ca.richyoung.mooshrevolt//gtk4
```

Omit `--bundle-dir` to build the release app first. CI uses a privileged
Flatpak builder container when ordinary sandbox creation is restricted.
Use `--out-dir` to choose where all Flatpak work is stored, including temporary
staging files, builder state/cache, repository, and the final bundle:

```sh
bash tools/build_flatpak_gtk4.sh \
  --bundle-dir build/linux-gtk4/x64/release/bundle \
  --out-dir /path/to/flatpak-work/mooshrevolt-gtk4
```

The default is `build/linux-gtk4/flatpak-output` in the project. Host builds put
builder files in `build/`, `state/`, and `repo/` under that directory; container
builds use `flatpak/`, `flatpak-state/`, and `flatpak-repo/`. Both write
`ca.richyoung.mooshrevolt.gtk4.flatpak` directly in the output directory. Temporary
staging files are removed when the script exits. Relative output paths resolve
from the calling directory. Use separate output directories for each variant
and for host versus container builds. The option is also forwarded to the
container builder in CI.

The `gtk4` branch is distinct from the existing GTK3 Flatpak. The sandbox
retains system D-Bus access to `org.bluez` for BLE and does not need access
to arbitrary host files. A successful UI launch does not prove access to a
physical Mooshimeter; verify scanning and connecting on a Bluetooth-enabled
host after installing the Flatpak.

## Artifact compatibility

The installer verifies that the engine's `gen_snapshot` and the downloaded Dart
SDK report the same version. Engine `e0462bb4b7f33fb7bf4c59ba2a73cfa1d0385ce1`
was observed shipping `gen_snapshot` version `3.15.0-47.0.dev` with SDK
`3.15.0-27.0.dev`. Release builds fail during AOT snapshot generation with
`ApiError`; the artifact publisher needs to rebuild or republish the matching
SDK and engine archives. The previous engine `409396163af31148a9f408ecd1db41acdb1e0e76`
passed the native GTK4 and Flatpak builds during this port.
