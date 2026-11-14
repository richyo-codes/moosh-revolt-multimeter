import 'dart:async';

import 'package:moosh_revolt/services/settings_service.dart';
import 'package:universal_ble/universal_ble.dart';

/// Finds only explicitly remembered, enabled targets; device names are labels.
/// Injected transport operations let tests exercise scan timing without BLE.
Future<BleDevice?> findStartupDevice({
  required SettingsProvider settings,
  required Future<List<BleDevice>> Function() systemDevices,
  required Stream<BleDevice> scanStream,
  required Future<void> Function() startScan,
  required Future<void> Function() stopScan,
  Duration scanTimeout = const Duration(seconds: 5),
}) async {
  final targets = settings.rememberedDevices
      .where((device) => device.autoConnect)
      .map((device) => device.address.toLowerCase())
      .toSet();
  if (!settings.autoConnect || targets.isEmpty) return null;
  bool matches(BleDevice device) =>
      targets.contains(device.deviceId.toLowerCase());

  try {
    final connected = await systemDevices().timeout(scanTimeout);
    for (final device in connected) {
      if (matches(device)) return device;
    }
  } catch (_) {
    // Some platforms do not expose system devices. Discovery can still work.
  }

  final found = Completer<BleDevice?>();
  // Subscribe before starting discovery, including synchronously emitted events.
  final subscription = scanStream.listen(
    (device) {
      if (!found.isCompleted && matches(device)) found.complete(device);
    },
    onError: (Object error, StackTrace trace) {
      if (!found.isCompleted) found.completeError(error, trace);
    },
    onDone: () {
      if (!found.isCompleted) found.complete(null);
    },
  );
  try {
    // One overall deadline: unrelated advertisements must not extend the scan.
    final result = await Future.wait<Object?>([
      Future<void>.sync(startScan),
      found.future,
    ], eagerError: true).timeout(scanTimeout, onTimeout: () => [null, null]);
    return result[1] as BleDevice?;
  } finally {
    await subscription.cancel();
    try {
      await stopScan().timeout(scanTimeout);
    } catch (_) {
      // Always release our listener, even when the platform cannot stop a scan.
    }
  }
}
