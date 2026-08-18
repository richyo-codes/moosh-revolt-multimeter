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
