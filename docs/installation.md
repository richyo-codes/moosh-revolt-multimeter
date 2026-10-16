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

### Flatpak

Locally built Flatpak bundles require `flatpak`, `flatpak-builder`, and the
Flathub Freedesktop 25.08 SDK/runtime:

```sh
./tools/build_flatpak.sh
flatpak install --user --reinstall build/ca.richyoung.mooshrevolt.flatpak
```

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

## macOS

MooshRevolt runs on macOS 12 or later, including macOS 27, using Core
Bluetooth. No pairing is needed. On first launch, macOS asks for Bluetooth
permission; allow it, or enable MooshRevolt later under
System Settings > Privacy & Security > Bluetooth.

Building from source requires Xcode and CocoaPods:

```sh
flutter pub get
flutter run -d macos
flutter build macos --release   # build/macos/Build/Products/Release/MooshRevolt.app
```

The app is sandboxed. Snapshots and CSV files are saved under
`~/Library/Containers/ca.richyoung.mooshrevolt/Data/Documents/Mooshimeter`.
The continuity tone is played with the built-in `afplay`. The standalone CSV
logger described below uses BlueZ and is Linux-only.

## Mock development mode

Launch directly into a simulated connected meter without Bluetooth hardware:

```sh
flutter run -d linux --dart-define=MOOSHREVOLT_MOCK=true
flutter run -d macos --dart-define=MOOSHREVOLT_MOCK=true
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
