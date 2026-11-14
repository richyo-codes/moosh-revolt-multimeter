import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/services/startup_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const address = 'AA:BB:CC:DD:EE:FF';
  final savedDevices = jsonEncode([
    {'address': '11:22:33:44:55:66', 'name': 'Saved', 'autoConnect': false},
  ]);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'autoconnect': false,
      'skip_upgrade': false,
      'sample_rate_hz': 250,
      'graph_max_points': 500,
      'dark_mode': false,
      'show_floating_readings': false,
      'language_code': 'fr',
      'remembered_devices': savedDevices,
    });
  });

  test(
    'operator overrides saved settings without persisting on connection',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final settings = SettingsProvider();
      await settings.init(
        configuration: StartupConfig.parse({
          'schemaVersion': 1,
          'autoConnect': true,
          'skipUpgrade': true,
          'sampleRateHz': 1000,
          'graphMaxPoints': 1200,
          'darkMode': true,
          'showFloatingReadings': true,
          'rememberedDevices': [
            {'address': address, 'name': 'Bench meter'},
          ],
        }),
      );
      expect(settings.autoConnect, isTrue);
      expect(settings.skipUpgrade, isTrue);
      expect(settings.sampleRate, 1000);
      expect(settings.graphMaxPoints, 1200);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.showFloatingReadings, isTrue);
      expect(settings.locale, const Locale('fr'));
      expect(
        settings.getRemembered(address.toLowerCase())?.name,
        'Bench meter',
      );
      expect(settings.rememberedDeviceCount, 1);
      // DeviceScreen does this automatically after a successful connection.
      await settings.rememberDevice(address.toLowerCase(), 'Advertised name');
      expect(settings.rememberedDeviceCount, 1);
      await settings.toggleDeviceAutoConnect(address.toLowerCase());
      await settings.unrememberDevice(address.toLowerCase());
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      final nextLaunch = SettingsProvider();
      await nextLaunch.init(configuration: StartupConfig.parse({}));
      expect(nextLaunch.sampleRate, 250);
      expect(nextLaunch.rememberedDevices.single.name, 'Saved');
    },
  );

  test(
    'empty configuration preserves preferences and normal UI persistence',
    () async {
      final settings = SettingsProvider();
      await settings.init(configuration: StartupConfig.parse({}));
      expect(settings.sampleRate, 250);
      expect(settings.themeMode, ThemeMode.light);
      settings.sampleRate = 500;
      await settings.rememberDevice(address, 'New');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('sample_rate_hz'), 500);
      expect(jsonDecode(prefs.getString('remembered_devices')!), hasLength(2));
    },
  );

  test('an explicit empty operator list replaces saved targets', () async {
    final settings = SettingsProvider();
    await settings.init(
      configuration: StartupConfig.parse({'rememberedDevices': []}),
    );
    expect(settings.rememberedDevices, isEmpty);
    expect(settings.getFirstRemembered(), isNull);
  });

  test('all supported sample rates and graph limits are accepted', () {
    for (final rate in [125, 250, 500, 1000, 2000, 4000, 8000]) {
      expect(
        StartupConfig.parse({'sampleRateHz': rate}).values['sampleRateHz'],
        rate,
      );
    }
    for (final limit in [2, 100000]) {
      expect(
        StartupConfig.parse({'graphMaxPoints': limit}).values['graphMaxPoints'],
        limit,
      );
    }
  });

  test('rejects malformed or unknown values rather than applying a subset', () {
    for (final input in [
      null,
      [],
      'text',
      {'schemaVersion': 2},
      {'schemaVersion': 1.0},
      {'schemaVersion': null},
      {'autoConnect': 'yes'},
      {'autoConnect': null},
      {'skipUpgrade': 1},
      {'darkMode': 'dark'},
      {'showFloatingReadings': 0},
      {'sampleRateHz': 126},
      {'sampleRateHz': 125.0},
      {'graphMaxPoints': 1},
      {'graphMaxPoints': 100001},
      {'graphMaxPoints': 2.0},
      {'unknown': true},
      {'rememberedDevices': null},
      {'rememberedDevices': {}},
      {
        'rememberedDevices': [
          {'address': 'AA', 'name': 'Invalid address'},
        ],
      },
      {
        'rememberedDevices': [
          {'address': address, 'name': ' '},
        ],
      },
      {
        'rememberedDevices': [
          {'address': address, 'name': 'One', 'autoConnect': 'false'},
        ],
      },
      {
        'rememberedDevices': [
          {'address': address, 'name': 'One', 'extra': true},
        ],
      },
      {
        'rememberedDevices': [
          {'address': address, 'name': 'One'},
          {'address': address.toLowerCase(), 'name': 'Two'},
        ],
      },
    ]) {
      expect(
        () => StartupConfig.parse(input),
        throwsFormatException,
        reason: '$input',
      );
    }
  });

  test('parsed devices are immutable and detached from the input map', () {
    final device = {'address': address.toLowerCase(), 'name': ' Bench '};
    final config = StartupConfig.parse({
      'rememberedDevices': [device],
    });
    device['name'] = 'Changed';
    expect(config.rememberedDevices!.single.address, address);
    expect(config.rememberedDevices!.single.name, 'Bench');
    expect(() => config.values['autoConnect'] = true, throwsUnsupportedError);
    expect(
      () => config.values['rememberedDevices'][0]['name'] = 'Changed',
      throwsUnsupportedError,
    );
  });

  test(
    'explicit config files load, and missing/invalid files fail closed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'moosh-config-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/config.json');
      await file.writeAsString('{"autoConnect": false, "sampleRateHz": 500}');
      expect(
        (await StartupConfig.load(path: file.path)).values['sampleRateHz'],
        500,
      );
      await file.writeAsString('{broken');
      await expectLater(
        StartupConfig.load(path: file.path),
        throwsFormatException,
      );
      await expectLater(
        StartupConfig.load(path: '${directory.path}/missing'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        StartupConfig.load(path: directory.path),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(StartupConfig.load(path: ' '), throwsFormatException);
    },
  );
}
