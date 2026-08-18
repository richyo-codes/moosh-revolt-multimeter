import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/services/mock_ble_provider.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

void main() {
  test('simulates a connected meter and publishes changing samples', () async {
    final provider = MockBleProvider();
    addTearDown(provider.disconnect);

    expect(provider.state, MmConnectionState.connected);
    expect(provider.device.name, 'MooshRevolt Mock Meter');
    expect(provider.rssi, -43);
    expect(provider.sdCardReady, isTrue);

    final initialTimestamp = provider.latestReadings.timestamp;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(provider.latestReadings.timestamp, greaterThan(initialTimestamp));
    expect(provider.latestReadings.ch2Value, inInclusiveRange(14.1, 14.4));
  });
}
