import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:flutter/foundation.dart';

/// Probe BlueZ independently so a missing adapter or daemon does not enter
/// Universal BLE's Linux initialization path. Recheck on each discovery attempt.
Future<bool> canDiscoverBluetooth() async {
  if (!Platform.isLinux) return true;

  final client = BlueZClient();
  try {
    await client.connect();
    final adapters = client.adapters;
    return adapters.isNotEmpty && adapters.first.powered;
  } catch (error) {
    debugPrint('BlueZ unavailable: $error');
    return false;
  } finally {
    await client.close();
  }
}
