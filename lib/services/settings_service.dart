import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:moosh_revolt/models/remembered_device.dart';
import 'package:moosh_revolt/services/startup_config.dart';

/// Manages app-wide settings using [shared_preferences].
/// Extends [ChangeNotifier] so screens can [context.watch] settings
/// (auto-connect, remembered devices, etc.) without manual subscriptions.
class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // --- Settings ---
  bool _autoConnect = true;
  bool _skipUpgrade = false;
  int _sampleRate = 125;
  int _graphMaxPoints = 300;
  bool _darkMode = false;
  bool _showFloatingReadings = false;
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

  // --- Remembered Devices ---
  List<RememberedDevice> _rememberedDevices = [];
  bool _operatorDeviceList = false;

  // --- Getters ---

  bool get autoConnect => _autoConnect;
  bool get skipUpgrade => _skipUpgrade;
  int get sampleRate => _sampleRate;
  int get graphMaxPoints => _graphMaxPoints;
  bool get showFloatingReadings => _showFloatingReadings;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
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
    _sampleRate = _normalizeSampleRate(_prefs?.getInt('sample_rate_hz') ?? 125);
    _graphMaxPoints = _prefs?.getInt('graph_max_points') ?? 300;
    _darkMode = _prefs?.getBool('dark_mode') ?? false;
    _showFloatingReadings = _prefs?.getBool('show_floating_readings') ?? false;

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
    _darkMode = values['darkMode'] as bool? ?? _darkMode;
    _showFloatingReadings =
        values['showFloatingReadings'] as bool? ?? _showFloatingReadings;
    _operatorDeviceList = config.rememberedDevices != null;
    _rememberedDevices = config.rememberedDevices ?? _rememberedDevices;
    notifyListeners();
  }

  // --- Connection Settings ---

  set autoConnect(bool value) {
    _autoConnect = value;
    _prefs?.setBool('autoconnect', value);
    notifyListeners();
  }

  set skipUpgrade(bool value) {
    _skipUpgrade = value;
    _prefs?.setBool('skip_upgrade', value);
    notifyListeners();
  }

  set sampleRate(int value) {
    _sampleRate = _normalizeSampleRate(value);
    _prefs?.setInt('sample_rate_hz', _sampleRate);
    notifyListeners();
  }

  static int _normalizeSampleRate(int value) {
    const supported = [125, 250, 500, 1000, 2000, 4000, 8000];
    return supported.firstWhere((rate) => rate >= value, orElse: () => 8000);
  }

  set graphMaxPoints(int value) {
    _graphMaxPoints = value;
    _prefs?.setInt('graph_max_points', value);
    notifyListeners();
  }

  set showFloatingReadings(bool value) {
    _showFloatingReadings = value;
    _prefs?.setBool('show_floating_readings', value);
    notifyListeners();
  }

  void toggleTheme() {
    _darkMode = !_darkMode;
    _prefs?.setBool('dark_mode', _darkMode);
    notifyListeners();
  }

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
