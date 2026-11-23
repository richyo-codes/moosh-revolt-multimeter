import 'dart:convert';

import 'package:moosh_revolt/models/remembered_device.dart';

import 'startup_config_stub.dart'
    if (dart.library.io) 'startup_config_io.dart'
    as platform;

/// Validated operator overrides, applied after saved preferences at startup.
class StartupConfig {
  StartupConfig._(this.values);

  final Map<String, dynamic> values;

  static Future<StartupConfig> load({String? path}) async {
    final text = await platform.readStartupConfig(path: path);
    return parse(text == null ? <String, dynamic>{} : jsonDecode(text));
  }

  static StartupConfig parse(dynamic input) {
    if (input is! Map || input.keys.any((key) => key is! String)) {
      throw const FormatException('configuration must be a JSON object');
    }
    const keys = {
      'schemaVersion',
      'autoConnect',
      'skipUpgrade',
      'sampleRateHz',
      'graphMaxPoints',
      'darkMode',
      'showFloatingReadings',
      'showExitMenu',
      'rememberedDevices',
    };
    for (final key in input.keys) {
      if (!keys.contains(key)) throw FormatException('unknown setting: $key');
    }
    if (input.containsKey('schemaVersion') &&
        (input['schemaVersion'] is! int || input['schemaVersion'] != 1)) {
      throw const FormatException(
        'unsupported schemaVersion; expected integer 1',
      );
    }
    for (final key in [
      'autoConnect',
      'skipUpgrade',
      'darkMode',
      'showFloatingReadings',
      'showExitMenu',
    ]) {
      if (input.containsKey(key) && input[key] is! bool) {
        throw FormatException('$key must be a boolean');
      }
    }
    if (input.containsKey('sampleRateHz') &&
        (input['sampleRateHz'] is! int ||
            ![
              125,
              250,
              500,
              1000,
              2000,
              4000,
              8000,
            ].contains(input['sampleRateHz']))) {
      throw const FormatException('unsupported sampleRateHz');
    }
    if (input.containsKey('graphMaxPoints') &&
        (input['graphMaxPoints'] is! int ||
            input['graphMaxPoints'] < 2 ||
            input['graphMaxPoints'] > 100000)) {
      throw const FormatException(
        'graphMaxPoints must be between 2 and 100000',
      );
    }
    final values = Map<String, dynamic>.from(input);
    if (input.containsKey('rememberedDevices')) {
      final devices = input['rememberedDevices'];
      if (devices is! List) {
        throw const FormatException('rememberedDevices must be an array');
      }
      final addresses = <String>{};
      final normalized = <Map<String, dynamic>>[];
      for (final device in devices) {
        if (device is! Map<String, dynamic> ||
            device.keys.any(
              (k) => !['address', 'name', 'autoConnect'].contains(k),
            ) ||
            device['address'] is! String ||
            !RegExp(
              r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$',
            ).hasMatch(device['address'] as String) ||
            device['name'] is! String ||
            (device['name'] as String).trim().isEmpty ||
            (device.containsKey('autoConnect') &&
                device['autoConnect'] is! bool)) {
          throw const FormatException(
            'invalid remembered device: expected Bluetooth MAC address, name, and optional boolean autoConnect',
          );
        }
        final address = (device['address'] as String).toUpperCase();
        if (!addresses.add(address)) {
          throw const FormatException('duplicate remembered device address');
        }
        normalized.add(
          Map<String, dynamic>.unmodifiable({
            ...device,
            'address': address,
            'name': (device['name'] as String).trim(),
          }),
        );
      }
      values['rememberedDevices'] = List<Map<String, dynamic>>.unmodifiable(
        normalized,
      );
    }
    return StartupConfig._(Map<String, dynamic>.unmodifiable(values));
  }

  List<RememberedDevice>? get rememberedDevices {
    final devices = values['rememberedDevices'] as List?;
    return devices
        ?.map(
          (dynamic device) => RememberedDevice(
            address: device['address'] as String,
            name: device['name'] as String,
            autoConnect: device['autoConnect'] as bool? ?? true,
            rememberedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList();
  }
}
