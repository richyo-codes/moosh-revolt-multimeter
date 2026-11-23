import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:moosh_revolt/models/math_channel.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/models/remembered_device.dart';
import 'package:moosh_revolt/services/startup_config.dart';

/// Manages app-wide settings using [shared_preferences].
/// Extends [ChangeNotifier] so screens can [context.watch] settings
/// (auto-connect, remembered devices, etc.) without manual subscriptions.
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // --- Settings ---
  bool _autoConnect = true;
  bool _autoReconnect = true;
  bool _skipUpgrade = false;
  int _graphMaxPoints = 300;
  int? _sampleRate;
  Duration _chartWindow = const Duration(minutes: 1);
  ThemeMode _themeMode = ThemeMode.system;
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;
  bool _showFloatingReadings = false;
  bool _showExitMenu = false;
  String? _languageCode;

  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  set languageCode(String? value) {
    if (value != null && !['en', 'fr'].contains(value)) return;
    _languageCode = value;
    if (value == null) {
      _prefs?.remove('language_code');
    } else {
      _prefs?.setString('language_code', value);
    }
    notifyListeners();
  }

  // --- Meter screen preferences, restored on the next start ---
  final List<bool> _showChannel = [true, true];
  final List<ChannelMode> _channelMode = [
    ChannelMode.current,
    ChannelMode.voltage,
  ];
  final List<DisplayUnit> _displayUnit = [DisplayUnit.auto, DisplayUnit.auto];
  String? _graphStyle;
  bool _continuityTone = false;
  MathFunction _mathFunction = MathFunction.off;
  bool _continuityGraph = false;
  double _readingsFraction = defaultReadingsFraction;

  // --- Prometheus exporter ---
  bool _exporterEnabled = false;
  int _exporterPort = 9471;
  bool _exporterAllowRemote = false;

  // --- Remembered Devices ---
  List<RememberedDevice> _rememberedDevices = [];
  bool _operatorDeviceList = false;

  // --- Getters ---

  bool get autoConnect => _autoConnect;
  bool get skipUpgrade => _skipUpgrade;
  int get graphMaxPoints => _graphMaxPoints;

  /// Re-establish a dropped Bluetooth link automatically.
  bool get autoReconnect => _autoReconnect;

  /// The preferred sample rate in Hz, or null to choose it from the
  /// measurement (125 Hz for DC, 4 kHz for AC).
  int? get sampleRate => _sampleRate;

  /// How much history the live chart keeps.
  Duration get chartWindow => _chartWindow;
  bool get showExitMenu => _showExitMenu;
  bool get showFloatingReadings => _showFloatingReadings;
  ThemeMode get themeMode => _themeMode;
  TemperatureUnit get temperatureUnit => _temperatureUnit;

  bool showChannel(int channel) => _showChannel[channel];
  ChannelMode channelMode(int channel) => _channelMode[channel];
  DisplayUnit displayUnit(int channel) => _displayUnit[channel];

  /// The graph style's name, or null for the default.
  String? get graphStyle => _graphStyle;
  bool get continuityTone => _continuityTone;

  /// The math channel shown as a third reading.
  MathFunction get mathFunction => _mathFunction;
  bool get continuityGraph => _continuityGraph;

  /// Share of the meter screen given to the readings; the chart gets the
  /// rest.
  double get readingsFraction => _readingsFraction;

  bool get exporterEnabled => _exporterEnabled;
  int get exporterPort => _exporterPort;

  /// Serve metrics to other machines rather than only this one.
  bool get exporterAllowRemote => _exporterAllowRemote;

  /// Chart history choices offered in the UI.
  static const chartWindows = [
    Duration(seconds: 10),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];
  List<RememberedDevice> get rememberedDevices =>
      List.unmodifiable(_rememberedDevices);
  int get rememberedDeviceCount => _rememberedDevices.length;

  // --- Initialization ---

  Future<void> init({StartupConfig? configuration}) async {
    // Invalid operator configuration must not fall back to saved meter targets.
    final config = configuration ?? await StartupConfig.load();
    _prefs = await SharedPreferences.getInstance();
    final savedLanguage = _prefs?.getString('language_code');
    _languageCode = ['en', 'fr'].contains(savedLanguage) ? savedLanguage : null;

    _autoConnect = _prefs?.getBool('autoconnect') ?? true;
    _skipUpgrade = _prefs?.getBool('skip_upgrade') ?? false;
    _graphMaxPoints = _prefs?.getInt('graph_max_points') ?? 300;
    _autoReconnect = _prefs?.getBool('auto_reconnect') ?? true;
    // A new key: the old one always held a fixed rate (125 Hz by default),
    // which would keep AC measurements from switching to 4 kHz.
    final storedRate =
        _prefs?.getInt('sample_rate') ?? _prefs?.getInt('sample_rate_hz') ?? 0;
    _sampleRate = storedRate <= 0 ? null : _normalizeSampleRate(storedRate);
    _chartWindow = Duration(
      seconds: _prefs?.getInt('chart_window_s') ?? _chartWindow.inSeconds,
    );
    _themeMode = _byName(
      ThemeMode.values,
      _prefs?.getString('theme_mode'),
      // Before the System option existed, dark mode was a plain switch.
      (_prefs?.getBool('dark_mode') ?? false)
          ? ThemeMode.dark
          : (_prefs?.containsKey('dark_mode') ?? false)
          ? ThemeMode.light
          : ThemeMode.system,
    );
    _showFloatingReadings = _prefs?.getBool('show_floating_readings') ?? false;
    _temperatureUnit = _byName(
      TemperatureUnit.values,
      _prefs?.getString('temperature_unit'),
      TemperatureUnit.celsius,
    );
    DisplayPreferences.temperature = _temperatureUnit;
    for (final channel in const [0, 1]) {
      final key = 'ch${channel + 1}';
      _showChannel[channel] =
          _prefs?.getBool('show_$key') ?? _showChannel[channel];
      final mode = _byName(
        ChannelMode.values,
        _prefs?.getString('mode_$key'),
        _channelMode[channel],
      );
      if (ChannelMode.forChannel(channel).contains(mode)) {
        _channelMode[channel] = mode;
      }
      _displayUnit[channel] = _byName(
        DisplayUnit.values,
        _prefs?.getString('display_unit_$key'),
        DisplayUnit.auto,
      );
    }
    // Only one channel can use the shared input; keep CH1's choice.
    if (_channelMode[0].usesSharedInput && _channelMode[1].usesSharedInput) {
      _channelMode[1] = ChannelMode.voltage;
    }
    _exporterEnabled = _prefs?.getBool('exporter_enabled') ?? false;
    _exporterPort = _prefs?.getInt('exporter_port') ?? _exporterPort;
    _exporterAllowRemote = _prefs?.getBool('exporter_allow_remote') ?? false;
    _graphStyle = _prefs?.getString('graph_style');
    _continuityTone = _prefs?.getBool('continuity_tone') ?? false;
    _mathFunction = _byName(
      MathFunction.values,
      _prefs?.getString('math_function'),
      MathFunction.off,
    );
    _continuityGraph = _prefs?.getBool('continuity_graph') ?? false;
    _readingsFraction =
        (_prefs?.getDouble('readings_fraction') ?? defaultReadingsFraction)
            .clamp(minReadingsFraction, maxReadingsFraction);

    // Load remembered devices
    _rememberedDevices = [];
    final raw = _prefs?.getString('remembered_devices');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _rememberedDevices = list
            .map((e) => RememberedDevice.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('[SettingsProvider] Failed to load remembered devices: $e');
        _rememberedDevices = [];
      }
    }

    final values = config.values;
    _autoConnect = values['autoConnect'] as bool? ?? _autoConnect;
    _skipUpgrade = values['skipUpgrade'] as bool? ?? _skipUpgrade;
    _sampleRate = values['sampleRateHz'] as int? ?? _sampleRate;
    _graphMaxPoints = values['graphMaxPoints'] as int? ?? _graphMaxPoints;
    if (values.containsKey('darkMode')) {
      _themeMode = values['darkMode'] as bool
          ? ThemeMode.dark
          : ThemeMode.light;
    }
    _showFloatingReadings =
        values['showFloatingReadings'] as bool? ?? _showFloatingReadings;
    _showExitMenu =
        Platform.isLinux && (values['showExitMenu'] as bool? ?? _isFlutterPi());
    _operatorDeviceList = config.rememberedDevices != null;
    _rememberedDevices = config.rememberedDevices ?? _rememberedDevices;
    notifyListeners();
  }

  static bool _isFlutterPi() {
    // The embedder owns the process, even when invoked through a launcher.
    try {
      return Link('/proc/self/exe').targetSync().split('/').last ==
          'flutter-pi';
    } on FileSystemException {
      return false;
    }
  }

  // --- Connection Settings ---

  set skipUpgrade(bool value) {
    _skipUpgrade = value;
    _prefs?.setBool('skip_upgrade', value);
    notifyListeners();
  }

  set graphMaxPoints(int value) {
    _graphMaxPoints = value;
    _prefs?.setInt('graph_max_points', value);
    notifyListeners();
  }

  void toggleTheme() {
    themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  set autoReconnect(bool value) {
    _autoReconnect = value;
    _prefs?.setBool('auto_reconnect', value);
    notifyListeners();
  }

  set autoConnect(bool value) {
    _autoConnect = value;
    _prefs?.setBool('autoconnect', value);
    notifyListeners();
  }

  set sampleRate(int? value) {
    _sampleRate = value == null ? null : _normalizeSampleRate(value);
    _prefs?.setInt('sample_rate', _sampleRate ?? 0);
    if (_sampleRate != null) {
      _prefs?.setInt('sample_rate_hz', _sampleRate!);
    } else {
      _prefs?.remove('sample_rate_hz');
    }
    notifyListeners();
  }

  static int _normalizeSampleRate(int value) {
    const supported = [125, 250, 500, 1000, 2000, 4000, 8000];
    return supported.firstWhere((rate) => rate >= value, orElse: () => 8000);
  }

  set chartWindow(Duration value) {
    _chartWindow = value;
    _prefs?.setInt('chart_window_s', value.inSeconds);
    notifyListeners();
  }

  set showFloatingReadings(bool value) {
    _showFloatingReadings = value;
    _prefs?.setBool('show_floating_readings', value);
    notifyListeners();
  }

  set temperatureUnit(TemperatureUnit value) {
    _temperatureUnit = value;
    DisplayPreferences.temperature = value;
    _prefs?.setString('temperature_unit', value.name);
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    _themeMode = value;
    _prefs?.setString('theme_mode', value.name);
    notifyListeners();
  }

  // --- Meter screen preferences ---

  void setShowChannel(int channel, bool visible) {
    _showChannel[channel] = visible;
    _prefs?.setBool('show_ch${channel + 1}', visible);
    notifyListeners();
  }

  void setChannelMode(int channel, ChannelMode mode) {
    _channelMode[channel] = mode;
    _prefs?.setString('mode_ch${channel + 1}', mode.name);
    notifyListeners();
  }

  void setDisplayUnit(int channel, DisplayUnit unit) {
    _displayUnit[channel] = unit;
    _prefs?.setString('display_unit_ch${channel + 1}', unit.name);
    notifyListeners();
  }

  set graphStyle(String? name) {
    _graphStyle = name;
    if (name == null) {
      _prefs?.remove('graph_style');
    } else {
      _prefs?.setString('graph_style', name);
    }
    notifyListeners();
  }

  set mathFunction(MathFunction value) {
    _mathFunction = value;
    _prefs?.setString('math_function', value.name);
    notifyListeners();
  }

  set continuityTone(bool value) {
    _continuityTone = value;
    _prefs?.setBool('continuity_tone', value);
    notifyListeners();
  }

  set continuityGraph(bool value) {
    _continuityGraph = value;
    _prefs?.setBool('continuity_graph', value);
    notifyListeners();
  }

  static const defaultReadingsFraction = 0.4;
  set exporterEnabled(bool value) {
    _exporterEnabled = value;
    _prefs?.setBool('exporter_enabled', value);
    notifyListeners();
  }

  set exporterPort(int value) {
    _exporterPort = value.clamp(1024, 65535);
    _prefs?.setInt('exporter_port', _exporterPort);
    notifyListeners();
  }

  set exporterAllowRemote(bool value) {
    _exporterAllowRemote = value;
    _prefs?.setBool('exporter_allow_remote', value);
    notifyListeners();
  }

  static const minReadingsFraction = 0.15;
  static const maxReadingsFraction = 0.7;

  set readingsFraction(double value) {
    _readingsFraction = value.clamp(minReadingsFraction, maxReadingsFraction);
    _prefs?.setDouble('readings_fraction', _readingsFraction);
    notifyListeners();
  }

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((value) => value.name == name).firstOrNull ?? fallback;

  // --- Remembered Device Helpers ---

  bool isRemembered(String address) {
    return getRemembered(address) != null;
  }

  RememberedDevice? getRemembered(String address) {
    return _rememberedDevices
        .where((d) => d.address.toLowerCase() == address.toLowerCase())
        .firstOrNull;
  }

  /// Remember a device. If already remembered, updates the name.
  Future<bool> rememberDevice(String address, String name) async {
    final existingIdx = _rememberedDevices.indexWhere(
      (d) => d.address.toLowerCase() == address.toLowerCase(),
    );

    if (existingIdx >= 0) {
      // Update existing entry, preserving rememberedAt
      final existing = _rememberedDevices[existingIdx];
      _rememberedDevices[existingIdx] = RememberedDevice(
        address: existing.address,
        name: name,
        autoConnect: existing.autoConnect,
        rememberedAt: existing.rememberedAt,
      );
    } else {
      _rememberedDevices.add(
        RememberedDevice(
          address: address,
          name: name,
          rememberedAt: DateTime.now(),
        ),
      );
    }

    return _persistRememberedDevices();
  }

  /// Unremember a device by address.
  Future<bool> unrememberDevice(String address) async {
    _rememberedDevices.removeWhere(
      (d) => d.address.toLowerCase() == address.toLowerCase(),
    );
    return _persistRememberedDevices();
  }

  /// Toggle autoConnect flag for a remembered device.
  Future<bool> toggleDeviceAutoConnect(String address) async {
    final idx = _rememberedDevices.indexWhere(
      (d) => d.address.toLowerCase() == address.toLowerCase(),
    );
    if (idx < 0) return false;

    final dev = _rememberedDevices[idx];
    _rememberedDevices[idx] = RememberedDevice(
      address: dev.address,
      name: dev.name,
      autoConnect: !dev.autoConnect,
      rememberedAt: dev.rememberedAt,
    );
    return _persistRememberedDevices();
  }

  Future<bool> _persistRememberedDevices() async {
    // Connecting automatically calls rememberDevice. Never copy the operator's
    // list (including UI edits to it) into the user's saved device preferences.
    if (_operatorDeviceList) {
      notifyListeners();
      return true;
    }
    if (_prefs == null) return false;
    final jsonList = _rememberedDevices.map((d) => d.toJson()).toList();
    final success = await _prefs!.setString(
      'remembered_devices',
      jsonEncode(jsonList),
    );
    if (success) notifyListeners();
    return success;
  }

  /// Resolve a remembered device by name or address.
  RememberedDevice? resolveDevice(String query) {
    final lower = query.toLowerCase();
    return _rememberedDevices.firstWhere(
      (d) =>
          d.address.toLowerCase() == lower ||
          d.name.toLowerCase() == lower ||
          d.name.toLowerCase().contains(lower),
      orElse: () =>
          RememberedDevice(address: '', name: '', rememberedAt: DateTime.now()),
    );
  }

  /// Get the first remembered device (for auto-connect).
  RememberedDevice? getFirstRemembered() {
    return _rememberedDevices.where((d) => d.autoConnect).firstOrNull;
  }
}

/// "10 s", "1 min", "1 h" for a chart history window.
String formatChartWindow(Duration window) {
  if (window.inHours >= 1 && window.inMinutes % 60 == 0) {
    return '${window.inHours} h';
  }
  if (window.inMinutes >= 1 && window.inSeconds % 60 == 0) {
    return '${window.inMinutes} min';
  }
  return '${window.inSeconds} s';
}
