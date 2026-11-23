# MooshRevolt

MooshRevolt is a modern, open-source Android, Linux, and macOS desktop client for the
Mooshimeter Bluetooth LE multimeter.

<p>
  <img src="docs/images/meter-desktop-light.png" alt="MooshRevolt on the desktop with current, voltage and a real-power math channel beside a live chart" width="960">
</p>
<p>
  <img src="docs/images/alternator-check-mobile-light.png" alt="MooshRevolt in portrait with simulated alternator readings" width="260">
  <img src="docs/images/meter-desktop-dark-config.png" alt="Dark theme with the CH1 configuration panel docked beside the live chart" width="560">
</p>
<p>
  <img src="docs/images/waveform-desktop-dark.png" alt="Waveform view showing a 50 Hz mains capture of current and voltage" width="560">
</p>

It is an independent community project for Mooshimeter V.1, built around its
configuration-tree BLE protocol. It is not affiliated with Mooshim Engineering.

## Features

- Live CH1 and CH2 readings: current, voltage (DC/AC), resistance, diode drop,
  auxiliary voltage, and internal temperature (°C or °F)
- Bench-meter behavior: auto-ranging over the meter's own ranges, overload
  (OL) display, a fixed decimal point, and a per-channel zero
- A math channel: real power, apparent power, power factor, and a type-K
  thermocouple
- Dual-axis, shared-axis, and split live charts with a time axis and a
  history window of 10 s to 1 h, plus a waveform (oscilloscope) view
- Continuity and shorted-diode tones, and a continuity graph
- Continuous CSV recording of every reading, CSV chart exports, and
  screenshots
- A Prometheus exporter and a Linux CSV logger
- Automatic reconnection when the Bluetooth link drops
- A resizable layout that remembers your channels, modes, units, and theme
  (System, Light, or Dark)
- A built-in meter guide: which jack does what, step-by-step recipes that
  set the meter up, and safety notes
- Meter settings, battery state, and SD-card logger status
- A deterministic mock meter for UI development and screenshots

## Get started

See [Installation](docs/installation.md) for Linux bundles, Android APKs, the macOS disk image,
building from source, and mock development mode. [Measurements](docs/measurements.md)
explains the modes, ranges, overload, zero, continuity, diode drop, the math
channel, the waveform view, and recording.

## Tools and development

- [Prometheus exporter](docs/prometheus.md)
- [Linux CSV logger](docs/installation.md#linux-csv-logger)
- [Protocol replay CLI](docs/installation.md#protocol-replay-cli)
- [UI verification and screenshot workflow](docs/ui-verification.md)
- [UX review](docs/ux-review.md)
- [Release and CI/CD setup](docs/releasing.md)
- [Project background](background.md)

The Mooshimeter transport and configuration-tree protocol live in the local
[`packages/mooshimeter_ble`](packages/mooshimeter_ble) package. Contributions
that improve compatibility, reliability, accessibility, packaging, and testing
are welcome.

## Yocto

The [Yocto layer](yocto/README.md) packages MooshRevolt for flutter-pi on
embedded Linux.

## Safety

This is early software. Verify readings independently before using it for
safety-critical, high-voltage, or other consequential work.

## Contributors

Thank you to the people helping improve MooshRevolt:

- [Richard Young](https://github.com/richyo-codes) — project creator and maintainer.
- [sorny](https://github.com/sorny) — macOS support, measurement and UI improvements,
  recording, and Prometheus integration developed in the
  [sorny fork](https://github.com/sorny/moosh-revolt-multimeter). Integrated into this repository with its original commit history preserved.

Thanks also to everyone who reports bugs, tests with real meters, and contributes
translations, documentation, and fixes. Git history records authorship for
individual contributions.

## License

Copyright 2026 Richard Young. Licensed under the
[GNU GPL v3.0](LICENSE).

### GTK4 Linux and Flatpak

An optional GTK4 runner and GNOME 51 Flatpak are available alongside GTK3.
See [GTK4 build instructions](docs/gtk4.md).
