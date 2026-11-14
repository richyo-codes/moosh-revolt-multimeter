import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores meter screen preferences after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SettingsProvider();
    await first.init();
    first
      ..setShowChannel(1, false)
      ..setChannelMode(0, ChannelMode.resistance)
      ..setDisplayUnit(0, DisplayUnit.kilo)
      ..graphStyle = 'split'
      ..continuityTone = true
      ..themeMode = ThemeMode.dark
      ..chartWindow = const Duration(hours: 1)
      ..readingsFraction = 0.25
      ..sampleRate = null;

    final restarted = SettingsProvider();
    await restarted.init();
    expect(restarted.showChannel(1), isFalse);
    expect(restarted.channelMode(0), ChannelMode.resistance);
    expect(restarted.displayUnit(0), DisplayUnit.kilo);
    expect(restarted.graphStyle, 'split');
    expect(restarted.continuityTone, isTrue);
    expect(restarted.themeMode, ThemeMode.dark);
    expect(restarted.chartWindow, const Duration(hours: 1));
    expect(restarted.readingsFraction, 0.25);
    expect(restarted.sampleRate, isNull);
  });

  test(
    'defaults to the system theme and migrates the old dark switch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final fresh = SettingsProvider();
      await fresh.init();
      expect(fresh.themeMode, ThemeMode.system);

      SharedPreferences.setMockInitialValues({'dark_mode': true});
      final migrated = SettingsProvider();
      await migrated.init();
      expect(migrated.themeMode, ThemeMode.dark);
    },
  );

  test('never restores both channels on the shared input', () async {
    SharedPreferences.setMockInitialValues({
      'mode_ch1': 'resistance',
      'mode_ch2': 'diode',
    });
    final settings = SettingsProvider();
    await settings.init();
    expect(settings.channelMode(0), ChannelMode.resistance);
    expect(settings.channelMode(1), ChannelMode.voltage);
  });
}
