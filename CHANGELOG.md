# MooshRevolt changelog

All notable changes to this project are documented here.

## Unreleased

### Added

- macOS support with Core Bluetooth, a sandboxed app bundle, and a native,
  low-latency continuity tone.
- Every measurement mode of the original app, configured by name from the
  meter's configuration tree: current and voltage (DC/AC), resistance,
  diode drop, auxiliary voltage (DC/AC), and internal temperature in °C.
- Auto-ranging over the meter's ranges, overload (OL) display, a per-channel
  zero offset, and automatic sample rate (125 Hz DC, 4 kHz AC).
- Prometheus exporter at `/metrics` (Settings → Integrations).
- Resizable readings/chart split, chart time axis, chart history window
  (10 s – 1 h), and a continuity graph.
- Saved preferences for channel visibility, modes, units, graph style,
  continuity options, layout, and theme (System/Light/Dark).
- [Measurements](docs/measurements.md), [Prometheus](docs/prometheus.md), and
  [UX review](docs/ux-review.md) documentation.

### Changed

- Readings use bench-meter formatting: the range sets the decimal point and
  the ADC resolution sets the digits.
- The overflow menu is grouped. Maximize chart replaces the static Graph
  View.
- Snapshots and screenshots are saved to `Downloads/MooshRevolt` on desktop.

### Fixed

- Diode drop, auxiliary voltage, the AC modes, and internal temperature
  selected the wrong meter input or none at all.
- Resistance showed "A" and was limited to the 1 kΩ range.
- The continuity tone stayed silent for shorted probes that read slightly
  negative, and started late.
- Charts wobbled and rescaled at sample rates above 125 Hz.
- A hidden channel stayed in the chart and could not be shown again.

### Earlier

- Modern Android and Linux Flutter client for the Mooshimeter BLE multimeter.
- Live dual-channel readings, graphing, continuity tone, recording, snapshots,
  device settings, SD-card logger status, and a Linux CSV logger.
- GitHub/Gitea-compatible CI and tagged Linux/Android release artifacts.
