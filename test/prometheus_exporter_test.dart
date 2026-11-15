import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/services/prometheus_exporter.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

class _Provider extends BleProvider {
  _Provider(this._readings, {this.fresh = true});

  final DeviceReadings? _readings;
  bool fresh;

  @override
  MmConnectionState get state => MmConnectionState.connected;
  @override
  DeviceReadings? get latestReadings => _readings;
  @override
  bool get hasFreshReadings => fresh;
  @override
  double get battery => 2.86;
  @override
  int get rssi => -43;
  @override
  DateTime? get lastReadingsAt => DateTime.fromMillisecondsSinceEpoch(1000);
  @override
  List<double> ranges(int channel) {
    final input = this.input(channel);
    return switch (input.shared ?? input.mapping) {
      'CURRENT' => const [10.0],
      'VOLTAGE' => const [60.0, 600.0],
      'TEMP' => const [350.0],
      _ => const [1e3, 1e4],
    };
  }
}

void main() {
  test('exports each channel as a base-unit metric', () {
    final provider = _Provider(
      DeviceReadings(ch1Value: 2.5, ch2Value: 14.24, timestamp: 0),
    );
    final text = renderPrometheusMetrics(provider);
    expect(
      text,
      contains(
        'mooshimeter_current_amperes{channel="1",mode="current",'
        'analysis="dc"} 2.5',
      ),
    );
    expect(
      text,
      contains(
        'mooshimeter_voltage_volts{channel="2",mode="voltage",'
        'analysis="dc"} 14.24',
      ),
    );
    expect(text, contains('# TYPE mooshimeter_current_amperes gauge'));
    expect(text, contains('mooshimeter_connected 1'));
    expect(text, contains('mooshimeter_battery_volts 2.86'));
    expect(text, contains('mooshimeter_rssi_dbm -43'));
    expect(text, contains('mooshimeter_overload{channel="1"} 0'));
    expect(
      text,
      contains('mooshimeter_range_full_scale{channel="2",unit="V"} 60.0'),
    );
  });

  test('converts temperature and names resistance in ohms', () async {
    final provider = _Provider(
      DeviceReadings(ch1Value: 298.15, ch2Value: 470, timestamp: 0),
    );
    await provider.setInput(0, ChannelMode.internalTemperature.input);
    await provider.setInput(1, ChannelMode.resistance.input);
    final text = renderPrometheusMetrics(provider);
    expect(text, contains('mooshimeter_temperature_celsius{channel="1"'));
    expect(text, matches(RegExp(r'temperature_celsius\{[^}]*\} 25\.0')));
    expect(text, contains('mooshimeter_resistance_ohms{channel="2"'));
  });

  test('exports Celsius while the display shows Fahrenheit', () async {
    DisplayPreferences.temperature = TemperatureUnit.fahrenheit;
    addTearDown(() => DisplayPreferences.temperature = TemperatureUnit.celsius);
    final provider = _Provider(
      DeviceReadings(ch1Value: 298.15, ch2Value: 1, timestamp: 0),
    );
    await provider.setInput(0, ChannelMode.internalTemperature.input);
    final text = renderPrometheusMetrics(provider);
    expect(text, matches(RegExp(r'temperature_celsius\{[^}]*\} 25\.0')));
  });

  test('omits stale and overloaded readings', () {
    final overloaded = _Provider(
      DeviceReadings(
        ch1Value: 2.5,
        ch2Value: 99,
        timestamp: 0,
        ch2Overload: true,
      ),
    );
    final text = renderPrometheusMetrics(overloaded);
    expect(text, isNot(contains('mooshimeter_voltage_volts{')));
    expect(text, contains('mooshimeter_overload{channel="2"} 1'));

    final stale = _Provider(
      DeviceReadings(ch1Value: 2.5, ch2Value: 14, timestamp: 0),
      fresh: false,
    );
    final staleText = renderPrometheusMetrics(stale);
    expect(staleText, isNot(contains('mooshimeter_current_amperes')));
    expect(staleText, contains('mooshimeter_connected 1'));
  });

  test(
    'real socket restricts wildcard to loopback and closes on disable',
    () async {
      final exporter = PrometheusExporter(BleProvider());
      addTearDown(exporter.stop);
      await exporter.configure(enabled: true, port: 0, allowRemote: true);
      expect(exporter.allowsRemote, isTrue);
      final port = Uri.parse(exporter.url!).port;
      await exporter.configure(enabled: true, port: port, allowRemote: false);
      expect(exporter.allowsRemote, isFalse);
      expect(exporter.url, 'http://127.0.0.1:$port/metrics');
      final client = HttpClient();
      addTearDown(client.close);
      final response = await (await client.getUrl(
        Uri.parse(exporter.url!),
      )).close();
      expect(response.statusCode, 200);
      await response.drain<void>();
      await exporter.configure(enabled: false, port: port, allowRemote: false);
      expect(exporter.running, isFalse);
      final probe = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await probe.close();
    },
  );

  test('serves /metrics over HTTP on loopback', () async {
    final provider = _Provider(
      DeviceReadings(ch1Value: 1, ch2Value: 2, timestamp: 0),
    );
    final exporter = PrometheusExporter(provider);
    // Find a free port, then hand it to the exporter.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    await exporter.configure(enabled: true, port: port, allowRemote: false);
    addTearDown(exporter.stop);

    expect(exporter.url, 'http://127.0.0.1:$port/metrics');
    final client = HttpClient();
    final request = await client.get('127.0.0.1', port, '/metrics');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    expect(response.statusCode, 200);
    expect(response.headers.contentType?.mimeType, 'text/plain');
    expect(body, contains('mooshimeter_current_amperes'));
    expect(body, contains('mooshimeter_exporter_scrapes_total 1'));

    await exporter.configure(enabled: false, port: port, allowRemote: false);
    expect(exporter.running, isFalse);
  });
}
