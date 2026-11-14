import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/services/startup_autoconnect.dart';
import 'package:moosh_revolt/services/startup_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const target = 'AA:BB:CC:DD:EE:FF';
  const disabled = '11:22:33:44:55:66';
  late SettingsProvider settings;
  late StreamController<BleDevice> events;
  late List<BleDevice> system;
  late int starts;
  late int stops;

  BleDevice device(String address, {String? name}) =>
      BleDevice(deviceId: address, name: name);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remembered_devices': jsonEncode([
        {'address': target, 'name': 'Bench', 'autoConnect': true},
        {'address': disabled, 'name': 'Disabled', 'autoConnect': false},
      ]),
    });
    settings = SettingsProvider();
    await settings.init(configuration: StartupConfig.parse({}));
    events = StreamController<BleDevice>.broadcast(sync: true);
    addTearDown(events.close);
    system = [];
    starts = stops = 0;
  });

  Future<BleDevice?> find({Future<void> Function()? start}) =>
      findStartupDevice(
        settings: settings,
        systemDevices: () async => system,
        scanStream: events.stream,
        startScan: () async {
          starts++;
          await start?.call();
        },
        stopScan: () async {
          stops++;
        },
        scanTimeout: const Duration(milliseconds: 40),
      );

  test(
    'system devices match enabled addresses without requiring a name',
    () async {
      system = [
        device(disabled, name: 'Mooshimeter'),
        device(target.toLowerCase()),
      ];
      expect((await find())?.deviceId, target.toLowerCase());
      expect(starts, 0);
    },
  );

  test(
    'scan ignores names and disabled targets and catches first advertisement',
    () async {
      system = [device(disabled, name: 'Mooshimeter')];
      final result = await find(
        start: () async {
          events.add(device('00:00:00:00:00:01', name: 'Mooshimeter Bench'));
          events.add(device(disabled, name: 'Mooshimeter'));
          events.add(device(target.toLowerCase(), name: 'Renamed'));
        },
      );
      expect(result?.deviceId, target.toLowerCase());
      expect(starts, 1);
      expect(stops, 1);
      expect(events.hasListener, isFalse);
    },
  );

  test('silent scan times out and releases the listener', () async {
    expect(await find(), isNull);
    expect(stops, 1);
    expect(events.hasListener, isFalse);
  });

  test('unrelated advertisements cannot reset the total timeout', () async {
    Timer? advertisements;
    addTearDown(() => advertisements?.cancel());
    expect(
      await find(
        start: () async {
          advertisements = Timer.periodic(const Duration(milliseconds: 2), (_) {
            events.add(device('00:00:00:00:00:01', name: 'Mooshimeter'));
          });
        },
      ),
      isNull,
    );
    expect(stops, 1);
    expect(events.hasListener, isFalse);
  });

  test('a stuck startScan also respects the deadline', () async {
    expect(await find(start: () => Completer<void>().future), isNull);
    expect(stops, 1);
    expect(events.hasListener, isFalse);
  });

  test('scan errors stop discovery and cancel the subscription', () async {
    await expectLater(
      find(
        start: () async {
          events.addError(StateError('transport unavailable'));
        },
      ),
      throwsStateError,
    );
    expect(stops, 1);
    expect(events.hasListener, isFalse);
  });

  test(
    'disabled global or per-meter autoconnect never starts discovery',
    () async {
      settings.autoConnect = false;
      expect(await find(), isNull);
      settings.autoConnect = true;
      await settings.toggleDeviceAutoConnect(target.toLowerCase());
      expect(settings.getFirstRemembered(), isNull);
      expect(await find(), isNull);
      expect(starts, 0);
      expect(stops, 0);
    },
  );
}
