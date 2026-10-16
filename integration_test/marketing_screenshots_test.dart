import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/models/math_channel.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';

const _deviceId = 'DE:MO:00:00:00:01';

/// A fixed afternoon start, so the chart's clock axis reads realistically.
final _sessionStart =
    DateTime(2026, 10, 16, 14, 30).millisecondsSinceEpoch / 1000;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture mobile alternator marketing screenshot', (tester) async {
    await _captureScenario(
      tester,
      GlobalKey(),
      await _ensureOutputDirectory(),
      name: 'alternator-check-mobile-light',
      size: const Size(390, 844),
      brightness: Brightness.light,
    );
  });

  testWidgets('capture compact landscape UI verification screenshot', (
    tester,
  ) async {
    await _captureScenario(
      tester,
      GlobalKey(),
      await _ensureOutputDirectory(),
      name: 'alternator-check-landscape-light',
      size: const Size(844, 390),
      brightness: Brightness.light,
    );
  });

  testWidgets('capture desktop screenshot with the power math channel', (
    tester,
  ) async {
    await _captureScenario(
      tester,
      GlobalKey(),
      await _ensureOutputDirectory(),
      name: 'meter-desktop-light',
      size: const Size(1280, 800),
      brightness: Brightness.light,
      setUp: (settings, provider) =>
          settings.mathFunction = MathFunction.realPower,
    );
  });

  testWidgets('capture desktop dark screenshot with channel configuration', (
    tester,
  ) async {
    await _captureScenario(
      tester,
      GlobalKey(),
      await _ensureOutputDirectory(),
      name: 'meter-desktop-dark-config',
      size: const Size(1280, 800),
      brightness: Brightness.dark,
      act: (tester) async {
        await tester.tap(find.byTooltip('Configure CH1 · Current DC'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('capture waveform screenshot', (tester) async {
    await _captureScenario(
      tester,
      GlobalKey(),
      await _ensureOutputDirectory(),
      name: 'waveform-desktop-dark',
      size: const Size(1280, 800),
      brightness: Brightness.dark,
      setUp: (settings, provider) async {
        await provider.setInput(0, ChannelMode.currentAc.input);
        await provider.setInput(1, ChannelMode.voltageAc.input);
        provider.showWaveform = true;
      },
    );
  });
}

Future<Directory> _ensureOutputDirectory() async {
  final output = Directory(_outputDirectory());
  await output.create(recursive: true);
  return output;
}

Future<void> _captureScenario(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Directory output, {
  required String name,
  required Size size,
  required Brightness brightness,
  FutureOr<void> Function(SettingsProvider, _MarketingBleProvider)? setUp,
  Future<void> Function(WidgetTester)? act,
}) async {
  final view = tester.view;
  final previousSize = view.physicalSize;
  final previousDpr = view.devicePixelRatio;
  view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    view
      ..physicalSize = previousSize
      ..devicePixelRatio = previousDpr;
  });

  final provider = _MarketingBleProvider();
  final settings = SettingsProvider();
  await setUp?.call(settings, provider);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<BleProvider>.value(value: provider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: brightness,
            ),
            useMaterial3: true,
          ),
          home: DeviceScreen(
            device: BleDevice(deviceId: _deviceId, name: 'MooshRevolt'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  for (var index = 0; index < 100; index++) {
    final time = index * 0.25;
    provider.publish(
      // Engine-running measurement: alternator charging at ~14.2 V, with a
      // small rectifier/engine-speed ripple and a changing accessory load.
      current:
          2.35 + 0.28 * math.sin(time * 0.75) + 0.09 * math.sin(time * 3.2),
      voltage:
          14.24 +
          0.055 * math.sin(time * 0.75 + 0.8) +
          0.018 * math.sin(time * 4.6),
      timestamp: _sessionStart + time,
    );
    await tester.pump(const Duration(milliseconds: 35));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
  await act?.call(tester);
  await _capture(tester, boundaryKey, output, name);
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  Directory output,
  String name,
) async {
  final renderObject = boundaryKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('Screenshot boundary is unavailable for $name.');
  }
  final image = await renderObject.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('Could not encode $name.');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  await File('${output.path}/$name.png').writeAsBytes(bytes);
}

String _outputDirectory() {
  const override = String.fromEnvironment('MARKETING_SCREENSHOT_DIR');
  return override.isEmpty ? 'build/marketing_screenshots' : override;
}

class _MarketingBleProvider extends BleProvider {
  DeviceReadings _reading = DeviceReadings(
    ch1Value: 2.35,
    ch2Value: 14.24,
    timestamp: 0,
  );

  @override
  MmConnectionState get state => MmConnectionState.connected;

  @override
  String? get deviceId => _deviceId;

  @override
  DeviceReadings get latestReadings => _reading;

  @override
  bool get hasFreshReadings => true;

  @override
  double get battery => 2.86;

  @override
  int get rssi => -43;

  @override
  Future<void> disconnect() async {}

  /// The range layout of a real Mooshimeter V.1, so screenshots show the
  /// bench-meter formatting of the default 10 A and 60 V ranges.
  @override
  List<double> ranges(int channel) =>
      channel == 0 ? const [10] : const [60, 600];

  bool showWaveform = false;

  @override
  bool get waveform => showWaveform;

  /// A 50 Hz mains capture: 256 samples at 4 kHz, voltage leading current.
  @override
  WaveformCapture? get latestWaveform {
    if (!showWaveform) return null;
    List<double> wave(double peak, double phase) => [
      for (var i = 0; i < 256; i++)
        peak * math.sin(2 * math.pi * 50 * i / 4000 + phase) +
            peak * 0.05 * math.sin(2 * math.pi * 150 * i / 4000 + phase),
    ];
    return WaveformCapture(
      ch1: wave(2.3, -0.5),
      ch2: wave(325, 0),
      samplePeriod: 1 / 4000,
    );
  }

  @override
  int get sampleRateHz => showWaveform ? 4000 : 125;

  void publish({
    required double current,
    required double voltage,
    required double timestamp,
  }) {
    _reading = showWaveform
        // AC RMS of the simulated mains capture.
        ? DeviceReadings(
            ch1Value: 1.63 + current * 0.002,
            ch2Value: 229.8 + voltage * 0.01,
            timestamp: timestamp,
          )
        : DeviceReadings(
            ch1Value: current,
            ch2Value: voltage,
            timestamp: timestamp,
            realPower: current * voltage * 0.98,
          );
    notifyListeners();
  }
}
