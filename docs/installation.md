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
Bluetooth. No pairing is needed.

### Install

1. Download `MooshRevolt-<version>-macos.dmg` from the release page.
2. Open the disk image and drag **MooshRevolt** to **Applications**.
3. Open MooshRevolt from Applications. When macOS asks for Bluetooth
   access, allow it. You can also allow it later under
   System Settings > Privacy & Security > Bluetooth.

Release images are signed and notarized only when the release workflow has
Apple Developer ID secrets (see [Releases](releasing.md)). Otherwise macOS
blocks the first launch because the app is from an unidentified developer.
To allow it, open System Settings > Privacy & Security, scroll to the
message about MooshRevolt, and select **Open Anyway**. You need to do this
only once.

### Build from source

Building from source requires Xcode. Select it and accept its license once:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

Then build and run:

```sh
flutter pub get
flutter run -d macos
flutter build macos --release   # build/macos/Build/Products/Release/MooshRevolt.app
./tools/build_dmg.sh            # build/MooshRevolt-<version>-macos.dmg
```

The app is sandboxed. CSV snapshots and screenshots are saved to
`~/Downloads/MooshRevolt`; the confirmation has a **Show** action that
reveals the file in Finder. The continuity tone is generated natively with
Core Audio, so it starts together with the reading. The standalone CSV logger
described below uses BlueZ and is Linux-only.

## Connection

When the Bluetooth link drops without **Disconnect**, for example when the
meter leaves the range, MooshRevolt reconnects on its own. It retries after
1, 2, 5, 10, 20 and then every 30 seconds, restores the measurement setup,
and keeps the chart history. Select **Stop reconnecting** to give up, or turn
off **Settings → Reconnect automatically**.

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

The logger sets CH1 to DC current (10 A) and CH2 to DC voltage, whatever
mode the meter was left in. CH2 uses the 60 V range unless you pass
`--voltage-range 600`; the meter does not auto-range while logging, so pick
the range for the highest voltage you expect. Saturated readings are written
as `OL`. Use `--help` for sample rate, scan timeout, and duration options. The app's
overflow menu can copy a matching logger command for the visible channels,
sample rate, and connected device.

## Protocol replay CLI

Replay captured BLE notifications without launching Flutter:

```sh
dart run tool/mooshimeter_protocol_cli.dart < capture.hex
```

Each input line is a notification expressed as hexadecimal bytes, including its
sequence byte. Blank lines and `#` comments are ignored.
