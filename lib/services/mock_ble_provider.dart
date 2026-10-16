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

  /// The range layout reported by a real Mooshimeter V.1 config tree.
  static const _ranges = {
    'CURRENT': [10.0],
    'VOLTAGE': [60.0, 600.0],
    'TEMP': [350.0],
    'AUX_V': [0.1, 0.3, 1.2],
    'RESISTANCE': [1e3, 1e4, 1e5, 1e6, 1e7],
    'DIODE': [1.2],
  };

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

  /// A simulated mains-like buffer in waveform mode: 50 Hz sine current and
  /// voltage with a little ripple, at the current sample rate.
  @override
  WaveformCapture? get latestWaveform {
    if (!waveform) return null;
    final rate = sampleRateHz;
    final n = rate >= 4000 ? 256 : 64;
    List<double> wave(double amplitude, double phase, double dc) => [
      for (var i = 0; i < n; i++)
        dc +
            amplitude * math.sin(2 * math.pi * 50 * i / rate + phase + _time) +
            amplitude * 0.04 * math.sin(2 * math.pi * 150 * i / rate),
    ];
    final current = input(0).isRms ? wave(2.3, 0.6, 0) : wave(0.3, 0, 2.35);
    final voltage = input(1).isRms ? wave(325, 0, 0) : wave(0.08, 0.8, 14.24);
    return WaveformCapture(ch1: current, ch2: voltage, samplePeriod: 1 / rate);
  }

  @override
  List<double> ranges(int channel) {
    final input = this.input(channel);
    return _ranges[input.shared ?? input.mapping] ?? const [];
  }

  @override
  int get sampleRateHz =>
      sampleRateSetting ?? (input(0).isRms || input(1).isRms ? 4000 : 125);

  @override
  Future<bool> connect(BleDevice device, {int? sampleRate}) async {
    await super.setSampleRate(sampleRate);
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
  Future<void> setSampleRate(int? rate) async {
    await super.setSampleRate(rate);
    _restartTimer();
  }

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
      milliseconds: math.max(20, 1000 ~/ math.min(sampleRateHz, 50)),
    );
    _timer = Timer.periodic(interval, (_) {
      _time += interval.inMilliseconds / 1000;
      final ch1 = _simulate(0);
      final ch2 = _simulate(1);
      _reading = DeviceReadings(
        ch1Value: ch1,
        ch2Value: ch2,
        timestamp: _time,
        ch1Overload: _overload(0, ch1),
        ch2Overload: _overload(1, ch2),
      );
      emitReadings(_reading);
      notifyListeners();
    });
  }

  /// Deterministic alternator-style values in the meter's native units.
  double _simulate(int channel) {
    final t = _time;
    final input = this.input(channel);
    final value = switch (input.shared ?? input.mapping) {
      'CURRENT' =>
        input.isRms
            ? 1.62 + 0.04 * math.sin(t * 0.9)
            : 2.35 + 0.28 * math.sin(t * 0.75) + 0.09 * math.sin(t * 3.2),
      'VOLTAGE' =>
        input.isRms
            ? 230.4 + 0.6 * math.sin(t * 0.5)
            : 14.24 +
                  0.055 * math.sin(t * 0.75 + 0.8) +
                  0.018 * math.sin(t * 4.6),
      'TEMP' => 298.4 + 0.2 * math.sin(t * 0.1),
      'AUX_V' => 0.0473 + 0.002 * math.sin(t * 1.3),
      // Alternates between probes touching and open every few seconds.
      'RESISTANCE' =>
        math.sin(t * 0.8) > 0 ? 0.6 + 0.3 * math.sin(t * 7) : 1.4e7,
      'DIODE' => 0.612 + 0.003 * math.sin(t * 2.1),
      _ => 0.0,
    };
    return value - offset(channel);
  }

  bool _overload(int channel, double value) {
    final values = ranges(channel);
    if (values.isEmpty) return false;
    final fullScale = values[rangeIndex(channel).clamp(0, values.length - 1)];
    return MeterRanges.isOverload(value + offset(channel), fullScale);
  }
}
