# MooshRevolt

MooshRevolt is a modern, open-source Android, Linux, and macOS desktop client for the
Mooshimeter Bluetooth LE multimeter.

<p>
  <img src="docs/images/alternator-check-mobile-light.png" alt="MooshRevolt in portrait with simulated alternator readings" width="300">
  <img src="docs/images/alternator-check-landscape-light.png" alt="MooshRevolt in landscape with simulated alternator readings" width="650">
</p>

It is an independent community project for Mooshimeter V.1, built around its
configuration-tree BLE protocol. It is not affiliated with Mooshim Engineering.

## Features

- Live CH1 and CH2 readings: current, voltage (DC/AC), resistance, diode drop,
  auxiliary voltage, and internal temperature
- Bench-meter behavior: auto-ranging over the meter's own ranges, overload
  (OL) display, a fixed decimal point, and a per-channel zero
- Dual-axis, shared-axis, and split live charts with a time axis and a
  history window of 10 s to 1 h
- Continuity tone and continuity graph
- A resizable layout that remembers your channels, modes, units, and theme
  (System, Light, or Dark)
- CSV snapshots, screenshots, a Prometheus exporter, and a Linux CSV logger
- Meter settings, battery state, and SD-card logger status
- A deterministic mock meter for UI development and screenshots

## Get started

See [Installation](docs/installation.md) for Linux bundles, Android APKs, the macOS disk image,
building from source, and mock development mode. [Measurements](docs/measurements.md)
explains the modes, ranges, overload, zero, continuity, and diode drop.

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

## Safety

This is early software. Verify readings independently before using it for
safety-critical, high-voltage, or other consequential work.

## License

Copyright 2026 Richard Young. Licensed under the
[GNU GPL v3.0](LICENSE).
