import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

/// Serves the live meter state at `/metrics` in the Prometheus text
/// exposition format, so readings can be scraped into Prometheus, Grafana
/// or any compatible collector.
class PrometheusExporter extends ChangeNotifier {
  PrometheusExporter(this._provider);

  static const defaultPort = 9471;

  final BleProvider _provider;
  HttpServer? _server;
  String? _error;
  int _scrapes = 0;

  bool get running => _server != null;

  /// Why the server could not start, for example a port already in use.
  String? get error => _error;

  /// The address being served, for example `http://127.0.0.1:9471/metrics`.
  String? get url {
    final server = _server;
    if (server == null) return null;
    final host = server.address.isLoopback ? '127.0.0.1' : server.address.host;
    final shown = host == '0.0.0.0' ? 'localhost' : host;
    return 'http://$shown:${server.port}/metrics';
  }

  /// Starts, restarts or stops the server to match the settings. Binding to
  /// all interfaces lets other machines scrape the meter; loopback keeps the
  /// readings on this computer.
  Future<void> configure({
    required bool enabled,
    required int port,
    required bool allowRemote,
  }) async {
    final address = allowRemote
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;
    final current = _server;
    if (enabled &&
        current != null &&
        current.port == port &&
        current.address == address) {
      return;
    }
    await stop();
    if (!enabled) return;
    try {
      final server = await HttpServer.bind(address, port);
      _server = server;
      _error = null;
      server.listen(_handle, onError: (Object _) {});
    } on SocketException catch (e) {
      _error = 'Cannot listen on port $port: ${e.osError?.message ?? e}';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    notifyListeners();
  }

  void _handle(HttpRequest request) {
    final response = request.response;
    if (request.uri.path == '/metrics') {
      _scrapes++;
      response.headers.contentType = ContentType(
        'text',
        'plain',
        parameters: {'version': '0.0.4', 'charset': 'utf-8'},
      );
      response.write(renderPrometheusMetrics(_provider, scrapes: _scrapes));
    } else if (request.uri.path == '/') {
      response.headers.contentType = ContentType.html;
      response.write(
        '<html><body><h1>MooshRevolt exporter</h1>'
        '<a href="/metrics">Metrics</a></body></html>',
      );
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    unawaited(response.close());
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

/// The metric a channel mode reports, following Prometheus naming: one
/// metric per physical quantity, named with its base unit.
({String name, String help, String analysis})? _metricFor(ChannelMode mode) =>
    switch (mode) {
      ChannelMode.current || ChannelMode.currentAc => (
        name: 'mooshimeter_current_amperes',
        help: 'Current measured on a channel.',
        analysis: mode.input.isRms ? 'ac_rms' : 'dc',
      ),
      ChannelMode.voltage ||
      ChannelMode.voltageAc ||
      ChannelMode.auxiliaryVoltageDc ||
      ChannelMode.auxiliaryVoltageAc => (
        name: 'mooshimeter_voltage_volts',
        help: 'Voltage measured on a channel.',
        analysis: mode.input.isRms ? 'ac_rms' : 'dc',
      ),
      ChannelMode.resistance => (
        name: 'mooshimeter_resistance_ohms',
        help: 'Resistance measured on a channel.',
        analysis: 'dc',
      ),
      ChannelMode.diode => (
        name: 'mooshimeter_diode_drop_volts',
        help: 'Diode forward voltage measured on a channel.',
        analysis: 'dc',
      ),
      ChannelMode.internalTemperature => (
        name: 'mooshimeter_temperature_celsius',
        help: 'Internal temperature of the meter.',
        analysis: 'dc',
      ),
    };

/// Renders the provider's state in the Prometheus text format (0.0.4).
///
/// Readings are only exported while they are fresh and in range: a
/// missing sample lets Prometheus mark the series stale instead of
/// recording the last value as if it were still true.
String renderPrometheusMetrics(BleProvider provider, {int scrapes = 0}) {
  final out = StringBuffer();
  void metric(String name, String type, String help, List<String> samples) {
    if (samples.isEmpty) return;
    out
      ..writeln('# HELP $name $help')
      ..writeln('# TYPE $name $type');
    for (final sample in samples) {
      out.writeln(sample);
    }
  }

  String number(double value) => value.isNaN
      ? 'NaN'
      : value.isInfinite
      ? (value > 0 ? '+Inf' : '-Inf')
      : '$value';

  final connected = provider.state == MmConnectionState.connected;
  final readings = connected && provider.hasFreshReadings
      ? provider.latestReadings
      : null;

  metric(
    'mooshimeter_connected',
    'gauge',
    'Whether a meter is connected (1) or not (0).',
    ['mooshimeter_connected ${connected ? 1 : 0}'],
  );

  // Group samples by metric name; both channels may report one quantity.
  final quantities = <String, ({String help, List<String> samples})>{};
  final overload = <String>[];
  final fullScale = <String>[];
  final autoRange = <String>[];
  final offset = <String>[];
  for (final channel in const [0, 1]) {
    final mode = provider.mode(channel);
    final quantity = _metricFor(mode)!;
    final labels =
        'channel="${channel + 1}",mode="${mode.name}",'
        'analysis="${quantity.analysis}"';
    if (readings != null) {
      // Prometheus wants base units: temperature stays in Celsius whatever
      // the display preference is.
      final shown = provider.displayValue(readings, channel);
      final value = mode == ChannelMode.internalTemperature && !shown.isNaN
          ? TemperatureUnit.celsius.fromKelvin(readings.value(channel))
          : shown;
      overload.add(
        'mooshimeter_overload{channel="${channel + 1}"} '
        '${value.isNaN ? 1 : 0}',
      );
      if (!value.isNaN) {
        quantities
            .putIfAbsent(
              quantity.name,
              () => (help: quantity.help, samples: <String>[]),
            )
            .samples
            .add('${quantity.name}{$labels} ${number(value)}');
      }
    }
    final range = provider.displayFullScale(channel);
    if (range != null) {
      fullScale.add(
        'mooshimeter_range_full_scale{channel="${channel + 1}",'
        'unit="${mode.units}"} ${number(range)}',
      );
    }
    autoRange.add(
      'mooshimeter_auto_range{channel="${channel + 1}"} '
      '${provider.autoRange(channel) ? 1 : 0}',
    );
    offset.add(
      'mooshimeter_offset{channel="${channel + 1}"} '
      '${number(provider.offset(channel))}',
    );
  }
  for (final entry in quantities.entries) {
    metric(entry.key, 'gauge', entry.value.help, entry.value.samples);
  }
  metric(
    'mooshimeter_overload',
    'gauge',
    'Whether the channel input exceeds its range (1) or not (0).',
    overload,
  );
  metric(
    'mooshimeter_range_full_scale',
    'gauge',
    'Full scale of the channel\'s active range in its display unit.',
    fullScale,
  );
  metric(
    'mooshimeter_auto_range',
    'gauge',
    'Whether the channel auto-ranges (1) or holds a range (0).',
    autoRange,
  );
  metric(
    'mooshimeter_offset',
    'gauge',
    'Zero offset the meter subtracts, in the meter\'s native unit.',
    offset,
  );

  if (connected) {
    metric(
      'mooshimeter_battery_volts',
      'gauge',
      'Battery voltage of the meter (two AA cells).',
      ['mooshimeter_battery_volts ${number(provider.battery)}'],
    );
    if (provider.rssi > -999) {
      metric(
        'mooshimeter_rssi_dbm',
        'gauge',
        'Bluetooth signal strength of the meter.',
        ['mooshimeter_rssi_dbm ${provider.rssi}'],
      );
    }
    metric(
      'mooshimeter_sample_rate_hertz',
      'gauge',
      'ADC sample rate of the meter.',
      ['mooshimeter_sample_rate_hertz ${provider.sampleRateHz}'],
    );
    metric(
      'mooshimeter_buffer_depth_samples',
      'gauge',
      'Samples averaged into each reading.',
      ['mooshimeter_buffer_depth_samples ${provider.bufferDepth}'],
    );
  }
  final last = provider.lastReadingsAt;
  if (last != null) {
    metric(
      'mooshimeter_last_reading_timestamp_seconds',
      'gauge',
      'Unix time of the latest reading.',
      [
        'mooshimeter_last_reading_timestamp_seconds '
            '${last.millisecondsSinceEpoch / 1000}',
      ],
    );
  }
  metric(
    'mooshimeter_exporter_scrapes_total',
    'counter',
    'Scrapes served by this exporter.',
    ['mooshimeter_exporter_scrapes_total $scrapes'],
  );
  return out.toString();
}
