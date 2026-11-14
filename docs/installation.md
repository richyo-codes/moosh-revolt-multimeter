# Installation and use

## Linux

Release builds are published as compressed Linux bundles. Extract a bundle and
run the `mooshrevolt` executable inside it. A running BlueZ service and powered
BLE adapter are required; pair the meter through the system UI if BlueZ asks.

To run from source:

```sh
flutter pub get
flutter run -d linux
```

Appliance images can supply [operator startup configuration](operator-config.md)
for remembered meters, autoconnect, sample rate, graph history, and appearance.

### Flatpak

Locally built Flatpak bundles require `flatpak`, `flatpak-builder`, and the
Flathub Freedesktop 25.08 SDK/runtime:

```sh
./tools/build_flatpak.sh
flatpak install --user --reinstall build/ca.richyoung.mooshrevolt.flatpak
```

Use `--out-dir` to put the Flatpak builder's working directory, state/cache,
export repository, and final bundle on another disk:

```sh
./tools/build_flatpak.sh --out-dir /path/to/flatpak-work/mooshrevolt-gtk3
```

That directory contains `flatpak/`, `flatpak-state/`, `flatpak-repo/`, and
`ca.richyoung.mooshrevolt.flatpak`. The default is the project's `build/`
directory. Relative paths resolve from the directory where you run the command;
paths with spaces must be quoted. The Flutter release bundle stays in
`build/linux/x64/release/bundle`; add `--skip-build` to reuse it, for example:

```sh
./tools/build_flatpak.sh --out-dir /path/to/flatpak-work/mooshrevolt-gtk3 --skip-build
```

The container helper supports the same output option:

```sh
./tools/build_flatpak_container.sh --out-dir /path/to/flatpak-work/mooshrevolt-container
```

It packages an existing release bundle and needs Podman or Docker. Use a separate
output directory for each GTK variant and for host versus container builds.
For GTK4, see [GTK4 Flatpak builds](gtk4.md#gtk4-flatpak).

The Flatpak uses the system BlueZ D-Bus service for Bluetooth LE access. Release
artifacts include a Flatpak bundle when the release workflow completes.

## Android

Tagged releases include a signed `mooshrevolt-android.apk`. Sideload it, enable
Bluetooth, and grant Android's nearby-device permission when prompted. Releases
are currently intended for direct installation rather than Play Store delivery.

To run from source on an attached device:

```sh
flutter pub get
flutter run
```

For local release-mode testing with the Android debug key:

```sh
cd android
./gradlew assembleRelease -PuseDebugSigning=true
```

The APK is written to `android/app/build/outputs/apk/release/app-release.apk`.
Tagged releases use the CI release keystore instead.

## Mock development mode

Launch directly into a simulated connected meter without Bluetooth hardware:

```sh
flutter run -d linux --dart-define=MOOSHREVOLT_MOCK=true
flutter run -d <device> --dart-define=MOOSHREVOLT_MOCK=true
```

Mock mode uses the real meter screen and controls with deterministic
alternator-style readings. It is useful for UI development and screenshots but
does not exercise the BLE transport.

## Linux CSV logger

The standalone pure-Dart Linux/BlueZ logger scans for the first Mooshimeter
unless a BLE address is supplied, performs the configuration-tree handshake,
and writes complete CH1/CH2 rows to CSV:

```sh
dart run tool/mooshimeter_log.dart --channel both --output readings.csv
dart run tool/mooshimeter_log.dart --device AA:BB:CC:DD:EE:FF --channel ch2 --output -
```

Use `--help` for sample rate, scan timeout, and duration options. The app's
overflow menu can copy a matching logger command for the visible channels,
sample rate, and connected device.

## Protocol replay CLI

Replay captured BLE notifications without launching Flutter:

```sh
dart run tool/mooshimeter_protocol_cli.dart < capture.hex
```

Each input line is a notification expressed as hexadecimal bytes, including its
sequence byte. Blank lines and `#` comments are ignored.
