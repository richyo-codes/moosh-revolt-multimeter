import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/services/mock_ble_provider.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';

const _testDeviceId = 'AA:BB:CC:DD:EE:FF';

void main() {
  Future<void> pumpDevice(
    WidgetTester tester, {
    required Size size,
    required BleProvider provider,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
          ChangeNotifierProvider<BleProvider>.value(value: provider),
        ],
        child: MaterialApp(
          home: DeviceScreen(
            device: BleDevice(
              deviceId: _testDeviceId,
              name: 'Test Mooshimeter',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses stacked readings on a mobile-sized viewport', (
    tester,
  ) async {
    await pumpDevice(
      tester,
      size: const Size(390, 844),
      provider: FakeBleProvider(ch1: 0.003, ch2: 1.2),
    );

    expect(
      find.byKey(const ValueKey('channel-readings-stacked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channel-readings-side-by-side')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('portrait-meter-layout')), findsOneWidget);
    expect(find.text('MooshRevolt'), findsOneWidget);
    expect(find.text('3.000'), findsOneWidget);
    expect(find.text('1.200'), findsOneWidget);
  });

  testWidgets('uses side-by-side readings on a desktop-sized viewport', (
    tester,
  ) async {
    await pumpDevice(
      tester,
      size: const Size(1280, 800),
      provider: FakeBleProvider(ch1: 0.003, ch2: 1.2),
    );

    expect(
      find.byKey(const ValueKey('channel-readings-side-by-side')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channel-readings-stacked')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('landscape-meter-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('realtime-chart-dualAxis')),
      findsOneWidget,
    );
  });

  testWidgets('keeps secondary controls in the overflow menu', (tester) async {
    await pumpDevice(
      tester,
      size: const Size(844, 390),
      provider: FakeBleProvider(ch1: 0.003, ch2: 1.2),
    );

    expect(
      find.byKey(const ValueKey('channel-readings-compact')),
      findsOneWidget,
    );
    expect(find.text('Record'), findsNothing);
    expect(find.byTooltip('Save screenshot'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Graph style: Dual axis'), findsOneWidget);
    expect(find.text('Sample rate: 125 Hz'), findsOneWidget);
    expect(find.text('Save screenshot'), findsOneWidget);
  });

  testWidgets('hides unavailable RSSI from the status rail', (tester) async {
    await pumpDevice(
      tester,
      size: const Size(390, 844),
      provider: FakeBleProvider(ch1: 0.003, ch2: 1.2, rssi: -999),
    );

    expect(find.textContaining('dBm'), findsNothing);
    expect(find.textContaining('Battery'), findsOneWidget);
    expect(find.text('0 samples'), findsOneWidget);
  });

  testWidgets('shows SD-card logging controls when the card is ready', (
    tester,
  ) async {
    await pumpDevice(
      tester,
      size: const Size(1280, 800),
      provider: FakeBleProvider(ch1: 0, ch2: 1.2, sdStatus: 0),
    );

    await tester.tap(find.byTooltip('Meter settings'));
    await tester.pumpAndSettle();

    expect(find.text('Device settings'), findsOneWidget);
    expect(find.text('SD Card Logging'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Log measurements to SD card'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Logging interval'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Logging interval'), findsOneWidget);
  });

  testWidgets('keeps the reconnect screen visible after disconnecting', (
    tester,
  ) async {
    final provider = FakeBleProvider(ch1: 0.003, ch2: 1.2);
    await pumpDevice(tester, size: const Size(390, 844), provider: provider);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(find.text('Meter disconnected'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('plots samples from the mock provider', (tester) async {
    final provider = MockBleProvider();
    addTearDown(provider.disconnect);
    await pumpDevice(tester, size: const Size(390, 844), provider: provider);

    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('0 samples'), findsNothing);
    expect(find.textContaining('samples'), findsOneWidget);
  });
}

class FakeBleProvider extends BleProvider {
  FakeBleProvider({
    required double ch1,
    required double ch2,
    this.sdStatus,
    this.rssi = -55,
  }) : _readings = DeviceReadings(ch1Value: ch1, ch2Value: ch2, timestamp: 1);

  final DeviceReadings _readings;
  final int? sdStatus;
  MmConnectionState _state = MmConnectionState.connected;
  @override
  final int rssi;

  @override
  MmConnectionState get state => _state;

  @override
  String? get deviceId => _testDeviceId;

  @override
  DeviceReadings? get latestReadings => _readings;

  @override
  bool get hasFreshReadings => true;

  @override
  double get battery => 2.85;

  @override
  int? get sdLogStatus => sdStatus;

  @override
  bool get sdCardReady => sdStatus == 0;

  @override
  String get sdCardStatusLabel =>
      sdStatus == 0 ? 'Ready' : 'Status not checked';

  @override
  Future<void> disconnect() async {
    _state = MmConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<bool> connect(BleDevice device, {int sampleRate = 125}) async {
    _state = MmConnectionState.connected;
    notifyListeners();
    return true;
  }

  @override
  Future<void> refreshSdLogging() async {}
}
