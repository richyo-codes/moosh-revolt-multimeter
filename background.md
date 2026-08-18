# MooshRevolt background

This document contains the project story, positioning notes, and instructions
for generating website screenshots. The main README stays focused on using and
developing MooshRevolt.

## Why this exists

I bought a Mooshimeter around 2016 and still think it is a remarkably useful
piece of hardware. It never had a dedicated Linux desktop application. The
sigrok/libsigrok ecosystem supports it, but I found that route unreliable in
practice. The Android app also predates modern Android expectations and its UI
did not work especially well for me.

This project is a fresh, common Flutter codebase for the two platforms I want
to use: a modern Android client and a proper Linux desktop application.

## Positioning

MooshRevolt is an independent, open-source companion for Mooshimeter V.1:

- Modern Android and Linux desktop UI
- Live dual-channel voltage and current measurements
- Graphing with independent channel visibility and display units
- Continuity mode with an audible tone on Linux
- Recording, snapshots, screenshots, and CSV logging
- A pure-Dart Linux/BlueZ CLI for unattended data capture

It is not affiliated with Mooshim Engineering. Avoid implying official
ownership, endorsement, or firmware support beyond what has been tested.

Suggested short description:

> A modern Android and Linux desktop client for the Mooshimeter Bluetooth LE
> multimeter.

Suggested longer description:

> A practical open-source companion for the Mooshimeter V.1, built with Flutter
> for modern Android and Linux desktop use. Capture live voltage and current,
> inspect trends, check continuity, record measurements, and log CSV data from
> the same device.

## Marketing screenshots

The deterministic screenshot test renders an engine-running alternator-check
fixture—about 14.2 V with realistic ripple and accessory-load current—without
requiring a physical meter connection. It produces desktop dark and mobile
light PNGs:

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux
```

Images are written to `build/marketing_screenshots` by default. Override that
location for a website asset pipeline:

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux \
  --dart-define=MARKETING_SCREENSHOT_DIR=/path/to/site/assets
```

Current generated assets:

- `alternator-check-desktop-dark.png` — 1440×900 desktop composition
- `alternator-check-mobile-light.png` — 390×844 mobile composition

The fixture simulates an engine-running alternator check: approximately 14.24 V
charging voltage with small rectifier/engine-speed ripple and a changing
accessory-load current around 2.35 A. This is representative of one practical
use of the hardware: diagnosing battery and alternator behavior under the hood.

The test source is
[`integration_test/marketing_screenshots_test.dart`](integration_test/marketing_screenshots_test.dart).
