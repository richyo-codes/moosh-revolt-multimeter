import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';

const _deviceId = 'DE:MO:00:00:00:01';

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
      timestamp: time,
    );
    await tester.pump(const Duration(milliseconds: 35));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
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

  void publish({
    required double current,
    required double voltage,
    required double timestamp,
  }) {
    _reading = DeviceReadings(
      ch1Value: current,
      ch2Value: voltage,
      timestamp: timestamp,
    );
    notifyListeners();
  }
}
