// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Connection';

  @override
  String get autoConnect => 'Auto-connect on launch';

  @override
  String get autoConnectHelp =>
      'Automatically reconnect to last remembered device';

  @override
  String get skipFirmware => 'Skip firmware check';

  @override
  String get skipFirmwareHelp => 'Skip OAD firmware update prompt';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get darkModeHelp => 'Use a dark color scheme throughout the app';

  @override
  String get showFloating => 'Show values for floating probes';

  @override
  String get showFloatingHelp =>
      'Keep displaying near-zero readings when a probe may be unconnected';

  @override
  String get rememberedDevices => 'Remembered Devices';

  @override
  String get noRemembered =>
      'No devices remembered yet. Connect to a device and tap \"Remember\" to save it.';

  @override
  String get forgetQuestion => 'Forget device?';

  @override
  String get cancel => 'Cancel';

  @override
  String get forget => 'Forget';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get dataCollection => 'Data Collection';

  @override
  String get defaultSampleRate => 'Default sample rate';

  @override
  String get maxGraphPoints => 'Max graph points';

  @override
  String get about => 'About';

  @override
  String get serviceUuids => 'BLE Service UUIDs';

  @override
  String get connectYourMeter => 'Connect your meter';

  @override
  String get wakeMeter => 'Wake your Mooshimeter and keep it nearby.';

  @override
  String get stopScanning => 'Stop scanning';

  @override
  String get findMeters => 'Find meters';

  @override
  String get savedMeters => 'Saved meters';

  @override
  String get autoConnectEnabled => 'Auto-connect enabled';

  @override
  String get savedConnect => 'Saved · tap to connect';

  @override
  String get knownDevices => 'Known to this computer';

  @override
  String get establishConnection => 'Open to establish a meter connection';

  @override
  String get nearbyMeters => 'Nearby meters';

  @override
  String get searchingMeters => 'Searching for nearby Mooshimeters…';

  @override
  String get savedHint => 'Connect a saved meter above, or search for another.';

  @override
  String get noMeters =>
      'No meters found yet. Check Bluetooth and try Find meters.';

  @override
  String get scan => 'Scan';

  @override
  String get stopScan => 'Stop Scan';

  @override
  String get meterSettings => 'Meter settings';

  @override
  String get graphView => 'Graph View';

  @override
  String get clearGraph => 'Clear graph';

  @override
  String get copyCsv => 'Copy CSV logger command';

  @override
  String get saveSnapshot => 'Save data snapshot';

  @override
  String get saveScreenshot => 'Save screenshot';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connectingMeter => 'Connecting to meter…';

  @override
  String get meterDisconnected => 'Meter disconnected';

  @override
  String get disconnectedHelp =>
      'The live readings have been cleared. Reconnect to resume sampling.';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connected => 'Connected';

  @override
  String get disconnecting => 'Disconnecting...';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get enableChannel => 'Enable a channel to show its reading';

  @override
  String get unitsHelp => 'Display units: Auto chooses an SI prefix';

  @override
  String get unitsAuto => 'Units: Auto';

  @override
  String get stopMinMax => 'Stop min/max tracking';

  @override
  String get trackMinMax => 'Track minimum and maximum values';

  @override
  String get outOfRange => 'OUT OF RANGE';

  @override
  String get waitingSample => 'Waiting for a fresh sample';

  @override
  String get possiblyFloating => 'Near zero · possibly floating';

  @override
  String get rememberDevice => 'Remember device';

  @override
  String get forgetDevice => 'Forget device';

  @override
  String get autoConnectNext => 'Auto-connect next time';

  @override
  String get rememberedTap => 'Remembered — tap to auto-connect';

  @override
  String get connect => 'Connect';

  @override
  String get live => 'Live';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get clearData => 'Clear Data';

  @override
  String get all => 'All';

  @override
  String get noSamples => 'No samples to save';

  @override
  String get sampleRate => 'Sample Rate';

  @override
  String get sdLogging => 'SD Card Logging';

  @override
  String get sdRefreshHint => 'Tap refresh to check the meter’s microSD card.';

  @override
  String get sdDetected =>
      'Card detected. The meter can log while disconnected.';

  @override
  String get sdInsert => 'Insert a FAT/FAT32 microSD card and refresh.';

  @override
  String get refreshSd => 'Refresh SD-card status';

  @override
  String get logToSd => 'Log measurements to SD card';

  @override
  String get loggingContinues => 'Logging continues after disconnecting.';

  @override
  String get loggingInterval => 'Logging interval';

  @override
  String get split => 'Split';

  @override
  String get dualAxis => 'Dual axis';

  @override
  String get shared => 'Shared';

  @override
  String get auto => 'Auto';

  @override
  String get voltageDc => 'Voltage DC';

  @override
  String get voltageAc => 'Voltage AC';

  @override
  String get currentDc => 'Current DC';

  @override
  String get currentAc => 'Current AC';

  @override
  String get internalTemperature => 'Internal Temperature';

  @override
  String get resistance => 'Resistance';

  @override
  String get diode => 'Diode Drop';

  @override
  String get frequency => 'Frequency';

  @override
  String get period => 'Period';

  @override
  String get auxDc => 'Auxiliary Voltage DC';

  @override
  String get auxAc => 'Auxiliary Voltage AC';

  @override
  String get inputRange => 'Input range';

  @override
  String get autoRecommended => 'Auto (recommended)';

  @override
  String get input60 => '60 V input';

  @override
  String get input600 => '600 V input';

  @override
  String get continuityTone => 'Continuity tone';

  @override
  String get defaultRange => 'Default input range';

  @override
  String get currentRangeHelp => 'CH1 current uses the 10 A input range.';

  @override
  String get resistanceRangeHelp =>
      'Resistance and continuity use the 1 kΩ input range.';

  @override
  String get defaultRangeHelp =>
      'This measurement uses the meter default range.';

  @override
  String get aboutApp => 'About MooshRevolt';

  @override
  String get modernClient => 'A modern Mooshimeter client';

  @override
  String get whyExists => 'Why it exists';

  @override
  String get license => 'License';

  @override
  String sampleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samples',
      one: '1 sample',
    );
    return '$_temp0';
  }

  @override
  String foundDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count devices',
      one: 'Found 1 device',
    );
    return '$_temp0';
  }

  @override
  String batteryPercent(int value) {
    return 'Battery $value%';
  }

  @override
  String savedPath(String path) {
    return 'Saved $path';
  }

  @override
  String configureChannel(String channel) {
    return 'Configure $channel';
  }

  @override
  String unitsValue(String unit) {
    return 'Units: $unit';
  }

  @override
  String graphStyle(String style) {
    return 'Graph style: $style';
  }

  @override
  String sampleRateValue(int rate) {
    return 'Sample rate: $rate Hz';
  }

  @override
  String removeDevice(String name) {
    return 'Remove \"$name\" from remembered devices?';
  }

  @override
  String deviceForgotten(String name) {
    return '$name forgotten';
  }

  @override
  String rememberedDate(String date) {
    return 'Remembered: $date';
  }

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String points(int count) {
    return 'Points: $count';
  }

  @override
  String lookingFor(String name) {
    return 'Looking for $name…';
  }

  @override
  String connectingTo(String name) {
    return 'Connecting to $name…';
  }

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get tapScan => 'Tap to scan';

  @override
  String get scanning => 'Scanning...';

  @override
  String get noneFound => 'No devices found';

  @override
  String get connectFailed => 'Could not connect — try again';

  @override
  String get deviceRemembered => 'Device remembered';

  @override
  String get forgotten => 'Device forgotten';

  @override
  String get showChannel => 'Show channel';

  @override
  String get showChannelHelp => 'Include this channel in readings and graph';

  @override
  String get continuityHelp => 'Play a continuous tone below 50 Ω';

  @override
  String get voltageAux => 'Voltage and auxiliary measurements';

  @override
  String get autoRangeHelp =>
      'Auto keeps normal measurements on the 60 V input and changes only when needed.';

  @override
  String get tempRangeHelp => 'Temperature mode does not use a voltage range.';

  @override
  String get loggingRangeHelp =>
      'Set a safe fixed input range before logging; the meter does not autorange while logging.';

  @override
  String get notRemembered => 'Not remembered';

  @override
  String get remember => 'Remember';

  @override
  String get deviceSettings => 'Device settings';

  @override
  String get graphStyleTitle => 'Graph style';

  @override
  String get sampleRateTitle => 'Sample rate';

  @override
  String get splitChannels => 'Split channels';

  @override
  String get sharedAxis => 'Shared axis';

  @override
  String get enableForCsv =>
      'Enable at least one channel before copying a logger command';

  @override
  String get appDescription =>
      'MooshRevolt is an Android and Linux desktop app for the Mooshimeter BLE multimeter. It provides live readings, graphing, logging, and a practical interface for modern devices.';

  @override
  String get appBackground =>
      'The project grew from using a Mooshimeter bought around 2016. There was no dedicated Linux desktop app, existing libsigrok support could be unreliable, and the original Android experience was not designed for current devices. MooshRevolt brings the meter to a shared Flutter codebase for Linux and Android.';

  @override
  String get licenseNotice =>
      'Copyright © Rich Young. Licensed under GNU GPL v3.0 or later. Source code and modified versions must remain available under the same license.';

  @override
  String meterNotFound(String name) {
    return 'Could not find \"$name\" — is it nearby ?';
  }

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System default';

  @override
  String get measurement => 'Measurement';

  @override
  String get currentAux => 'Current, resistance, and auxiliary measurements';

  @override
  String get device => 'Device';

  @override
  String get statusUnchecked => 'Status not checked';

  @override
  String get ready => 'Ready';

  @override
  String get excellent => 'Excellent';

  @override
  String get good => 'Good';

  @override
  String get fair => 'Fair';

  @override
  String get weak => 'Weak';

  @override
  String cardUnavailable(int status) {
    return 'Card unavailable (status $status)';
  }

  @override
  String batteryVoltage(String voltage) {
    return '$voltage V measured across two AA cells';
  }

  @override
  String get waitingSamples => 'Waiting for samples…';

  @override
  String get currentAxis => 'Current (A)';

  @override
  String get voltageAxis => 'Voltage (V)';

  @override
  String rememberedMeter(String name, String address) {
    return 'Remembered: $name ($address)';
  }
}
