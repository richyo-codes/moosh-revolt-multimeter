import 'dart:async';
import 'dart:math' as math;

import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:universal_ble/universal_ble.dart';

/// A deterministic connected-meter simulation for UI development.
///
/// Enable it with `--dart-define=MOOSHREVOLT_MOCK=true`. The simulator keeps
/// the real device screen and controls in use, but does not touch Bluetooth.
class MockBleProvider extends BleProvider {
  static const mockDeviceId = 'MOCK-MOOSHREVOLT-01';

  MmConnectionState _state = MmConnectionState.connected;
  DeviceReadings _reading = DeviceReadings(
    ch1Value: 2.35,
    ch2Value: 14.24,
    timestamp: 0,
  );
  Timer? _timer;
  double _time = 0;
  int _sampleRate = 125;
  bool _continuityEnabled = false;

  MockBleProvider() {
    _start();
  }

  BleDevice get device =>
      BleDevice(deviceId: mockDeviceId, name: 'MooshRevolt Mock Meter');

  @override
  MmConnectionState get state => _state;

  @override
  String? get deviceId =>
      _state == MmConnectionState.connected ? mockDeviceId : null;

  @override
  DeviceReadings get latestReadings => _reading;

  @override
  bool get hasFreshReadings => _state == MmConnectionState.connected;

  @override
  double get battery => 2.86;

  @override
  int get rssi => -43;

  @override
  int? get sdLogStatus => 0;

  @override
  bool get sdCardReady => true;

  @override
  String get sdCardStatusLabel => 'Ready (simulated)';

  @override
  Future<bool> connect(BleDevice device, {int sampleRate = 125}) async {
    _sampleRate = sampleRate;
    _state = MmConnectionState.connected;
    _start();
    notifyListeners();
    return true;
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _state = MmConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> setSampleRate(int rate) async {
    _sampleRate = rate;
    _restartTimer();
  }

  @override
  Future<void> setContinuityEnabled(bool enabled) async {
    _continuityEnabled = enabled;
    notifyListeners();
  }

  @override
  Future<void> setRange(int channel, int range) async {}

  @override
  Future<void> setVoltageRange(int? rangeIndex) async {}

  @override
  Future<void> setInputMode(int channel, int mode) async {}

  @override
  Future<void> refreshSdLogging() async {}

  @override
  Future<void> setSdLoggingEnabled(bool enabled) async {}

  @override
  Future<void> setSdLogIntervalSeconds(int seconds) async {}

  void _start() {
    if (_timer != null) return;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_state != MmConnectionState.connected) return;
    // The real UI does not need a notification for every simulated sample;
    // 25 Hz keeps the screen lively while avoiding needless rebuild pressure.
    final interval = Duration(
      milliseconds: math.max(20, 1000 ~/ math.min(_sampleRate, 50)),
    );
    _timer = Timer.periodic(interval, (_) {
      _time += interval.inMilliseconds / 1000;
      final current = _continuityEnabled
          ? 24 + 4 * math.sin(_time * 1.7)
          : 2.35 + 0.28 * math.sin(_time * 0.75) + 0.09 * math.sin(_time * 3.2);
      final voltage =
          14.24 +
          0.055 * math.sin(_time * 0.75 + 0.8) +
          0.018 * math.sin(_time * 4.6);
      _reading = DeviceReadings(
        ch1Value: current,
        ch2Value: voltage,
        timestamp: _time,
      );
      notifyListeners();
    });
  }
}
