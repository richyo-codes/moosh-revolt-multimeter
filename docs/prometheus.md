# Prometheus exporter

MooshRevolt can serve the live meter state over HTTP in the Prometheus text
format. Prometheus, Grafana Agent, VictoriaMetrics and other compatible
collectors can scrape it for long-term logging and dashboards.

## Turn it on

Open **Settings → Integrations → Prometheus exporter**. The endpoint is
served while the app runs:

```
http://127.0.0.1:9471/metrics
```

- **Port:** defaults to 9471. Enter another port and press Enter to apply it.
- **Allow access from other devices:** off by default, so only the local
  computer can read the measurements. Turn it on to bind all interfaces, for
  example when Prometheus runs on another machine. Anyone on your network can
  then read the readings.

The macOS app is sandboxed and declares the `network.server` entitlement for
this endpoint.

## Scrape configuration

```yaml
scrape_configs:
  - job_name: mooshrevolt
    scrape_interval: 1s
    static_configs:
      - targets: ["127.0.0.1:9471"]
```

The meter produces about two readings per second at 125 Hz (DC) and about 16
per second at 4 kHz (AC). Scrape intervals below one second only repeat
values.

## Metrics

Each measurement uses one metric per physical quantity, named with its base
unit. The `channel` label is `1` or `2`, `mode` is the channel mode, and
`analysis` is `dc` or `ac_rms`.

| Metric | Meaning |
| --- | --- |
| `mooshimeter_voltage_volts` | Voltage (DC, AC RMS, or auxiliary input) |
| `mooshimeter_current_amperes` | Current (DC or AC RMS) |
| `mooshimeter_resistance_ohms` | Resistance |
| `mooshimeter_diode_drop_volts` | Diode forward voltage |
| `mooshimeter_temperature_celsius` | Internal temperature of the meter |
| `mooshimeter_overload` | `1` while a channel's input exceeds its range |
| `mooshimeter_range_full_scale` | Full scale of the active range, with a `unit` label |
| `mooshimeter_auto_range` | `1` while a channel auto-ranges |
| `mooshimeter_offset` | Zero offset the meter subtracts, in its native unit |
| `mooshimeter_connected` | `1` while a meter is connected |
| `mooshimeter_battery_volts` | Battery voltage (two AA cells) |
| `mooshimeter_rssi_dbm` | Bluetooth signal strength, where available |
| `mooshimeter_sample_rate_hertz` | ADC sample rate |
| `mooshimeter_buffer_depth_samples` | Samples averaged into each reading |
| `mooshimeter_last_reading_timestamp_seconds` | Unix time of the latest reading |
| `mooshimeter_exporter_scrapes_total` | Scrapes served |

Readings appear only while they are fresh and in range. When the meter
disconnects, stops sending, or overloads, the measurement series are left out
of the response. Prometheus then marks them stale instead of recording the
last value as if it were still true. Use `mooshimeter_overload` and
`mooshimeter_connected` to tell these cases apart.

Example: chart CH2 voltage in Grafana with
`mooshimeter_voltage_volts{channel="2"}`, and alert on a disconnected meter
with `mooshimeter_connected == 0`.
