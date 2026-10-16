import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'meter_input.dart';
import 'mooshimeter_protocol.dart';

/// CRC32 lookup table (standard polynomial 0xEDB88320).
// ignore: avoid_classes_with_only_static_members
class _Crc32 {
  static final List<int> _table = List<int>.generate(256, (i) {
    var crc = i;
    for (var j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (crc & 1 == 1 ? 0xEDB88320 : 0);
    }
    return crc;
  });

  static int compute(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc = _table[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }
}

/// GATT characteristics for the Mooshimeter config tree protocol.
/// The device uses TWO characteristics for ALL communication:
///   - 1bc5ffa1 (write-only)  → send packets TO meter
///   - 1bc5ffa2 (notify)      → receive packets FROM meter
class MooshimeterUUIDs {
  static const String meterService = '1bc5ffa0-0200-62ab-e411-f254e005dbd4';
  static const String writeChar = '1bc5ffa1-0200-62ab-e411-f254e005dbd4';
  static const String readChar = '1bc5ffa2-0200-62ab-e411-f254e005dbd4';
}

/// Config tree node IDs (from sigrok.org/wiki protocol spec).
class ConfigNode {
  // Admin nodes (always available)
  static const int adminCrc32 = 0;
  static const int adminTree = 1;
  static const int adminDiag = 2;
  // System nodes
  static const int pcbVersion = 3;
  static const int name = 4;
  static const int timeUtc = 5;
  static const int timeUtcMs = 6;
  static const int batV = 7; // Float (battery voltage)
  static const int reboot = 8;
  // Sampling
  static const int samplingRate = 9;
  static const int samplingDepth = 10;
  static const int samplingTrigger = 11;
  // Logging
  static const int logOn = 12;
  static const int logInterval = 13;
  static const int logStatus = 14;
  static const int logPollDir = 15;
  static const int logInfoIndex = 16;
  static const int logInfoEnd = 17;
  static const int logInfoNBytes = 18;
  static const int logStreamIndex = 19;
  static const int logStreamOffset = 20;
  static const int logStreamData = 21;
  // CH1
  static const int ch1Mapping = 22;
  static const int ch1RangeI = 23;
  static const int ch1Analysis = 24;
  static const int ch1Value = 25; // Float (channel 1 reading)
  static const int ch1Offset = 26;
  static const int ch1Buf = 27;
  static const int ch1BufBps = 28;
  static const int ch1BufLsb2Native = 29;
  // CH2
  static const int ch2Mapping = 30;
  static const int ch2RangeI = 31;
  static const int ch2Analysis = 32;
  static const int ch2Value = 33; // Float (channel 2 reading)
  static const int ch2Offset = 34;
  static const int ch2Buf = 35;
  static const int ch2BufBps = 36;
  static const int ch2BufLsb2Native = 37;
  // Shared
  static const int shared = 38;
  static const int realPwr = 39;
}

/// Reading data from both channels.
class DeviceReadings {
  /// Channel values in the meter's native units (amps, volts, ohms, and
  /// kelvin for temperature), with the channel offset already removed.
  final double ch1Value;
  final double ch2Value;
  final double timestamp;

  /// Whether a channel's input was saturated on its current range. The value
  /// is then meaningless and should be shown as overload ("OL").
  final bool ch1Overload;
  final bool ch2Overload;

  /// Real power in watts, which the meter computes from the CH1 and CH2
  /// sample buffers (REAL_PWR). Meaningful when CH1 measures current and
  /// CH2 voltage; null until the meter has sent it.
  final double? realPower;

  DeviceReadings({
    required this.ch1Value,
    required this.ch2Value,
    required this.timestamp,
    this.ch1Overload = false,
    this.ch2Overload = false,
    this.realPower,
  });

  double value(int channel) => channel == 0 ? ch1Value : ch2Value;
  bool overload(int channel) => channel == 0 ? ch1Overload : ch2Overload;

  @override
  String toString() =>
      'DeviceReadings(ch1: $ch1Value, ch2: $ch2Value, ts: $timestamp)';
}

/// BLE connection state.
enum MmConnectionState { disconnected, connecting, connected, disconnecting }

/// Handles the Mooshimeter **config tree protocol** over BLE.
///
/// Protocol (per sigrok.org/wiki):
/// 1. Subscribe to `1bc5ffa2` notifications (incoming packets)
/// 2. Write a "read packet" to `1bc5ffa1`: [seqNum=0x01] [nodeId=0x01]
///    (NodeID 1 = ADMIN:TREE, upper bit = 0 for read)
/// 3. Meter responds with: [seqNum] [nodeId=0x81] [binary data...]
/// 4. After handshake, send read commands for CH1.VALUE (Node 25)
///    and CH2.VALUE (Node 33) — responses come as Float values.
///
/// Packet format:
///   Header (2 bytes):
///     Byte 0: SeqNum (sequence number, incremented per command)
///     Byte 1: NodeID (7-bit ID, bit 7 = 1 if writing/app→meter, 0 for read/meter→app)
///   Payload: value bytes (varies by node type)
class BleProvider extends ChangeNotifier {
  String? _deviceId;
  MmConnectionState _state = MmConnectionState.disconnected;

  // Config tree state
  int _nextSeqNum = 1;
  bool _handshakeDone = false;
  bool _readingStreamActive = false;
  bool _readingPollInProgress = false;
  bool _transportConnected = false;

  // Measurement configuration. It belongs to the app session rather than
  // the link, so it survives a disconnect and is re-applied on reconnect.
  final List<MeterInput> _inputs = [
    MeterInput.ch1Default,
    MeterInput.ch2Default,
  ];
  final List<bool> _autoRange = [true, true];
  final List<int> _rangeIndex = [0, 0];
  final List<double> _offsets = [0, 0];
  int? _sampleRateSetting;
  int _sampleRateIndex = 0;
  int _bufferDepth = 64;
  bool _rangeChangeInProgress = false;

  // Automatic reconnection after an unexpected link loss.
  BleDevice? _lastDevice;
  bool _autoReconnect = true;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _reconnecting = false;

  /// Delays between reconnection attempts; the last one repeats.
  static const reconnectBackoff = [1, 2, 5, 10, 20, 30];
  final MooshimeterSerialReassembler _serialReassembler =
      MooshimeterSerialReassembler();
  final MooshimeterFrameDecoder _frameDecoder = MooshimeterFrameDecoder();
  MooshimeterNode? _tree;

  // Config tree node value cache (updated by incoming packets)
  double _ch1Value = 0.0;
  double _ch2Value = 0.0;
  double _battery = 0.0;
  int? _sdLogStatus;
  bool _sdLoggingEnabled = false;
  int _sdLogIntervalSeconds = 1;
  int _ch1ValueNodeId = ConfigNode.ch1Value;
  int _ch2ValueNodeId = ConfigNode.ch2Value;
  int _batteryNodeId = ConfigNode.batV;
  int _realPowerNodeId = ConfigNode.realPwr;
  double? _realPower;

  // RSSI (not available on Linux, cached for display)
  int _rssi = -999;

  // Current observable readings
  DeviceReadings? _latestReadings;
  DateTime? _lastReadingsAt;
  DateTime? _discardReadingsUntil;
  // Synchronous, so listeners see each sample together with the
  // configuration that produced it (a recorder labels rows by mode).
  final StreamController<DeviceReadings> _readingsController =
      StreamController<DeviceReadings>.broadcast(sync: true);

  int get rssi => _rssi;

  StreamSubscription? _connectionSub;
  StreamSubscription? _packetSub;
  Timer? _readingPollTimer;
  Timer? _readingFreshnessTimer;

  // --- Public API ---

  MmConnectionState get state => _state;
  String? get deviceId => _deviceId;
  DeviceReadings? get latestReadings => _latestReadings;
  DateTime? get lastReadingsAt => _lastReadingsAt;
  Duration? get readingsAge => _lastReadingsAt == null
      ? null
      : DateTime.now().difference(_lastReadingsAt!);
  bool get hasFreshReadings {
    final age = readingsAge;
    return _latestReadings != null &&
        age != null &&
        age <= const Duration(milliseconds: 750);
  }

  /// Complete CH1/CH2 readings, emitted after the CH2 response in each poll.
  ///
  /// This is useful for non-UI clients that need one coherent CSV row per
  /// meter polling cycle rather than a notification for each individual node.
  Stream<DeviceReadings> get readings => _readingsController.stream;

  /// Publishes a complete sample on [readings]; for simulated providers.
  @protected
  void emitReadings(DeviceReadings readings) =>
      _readingsController.add(readings);
  double get battery => _battery;
  bool get isConnected => _state == MmConnectionState.connected;

  /// Whether a dropped link is being re-established automatically.
  bool get isReconnecting => _reconnecting;

  /// Attempts made since the link dropped.
  int get reconnectAttempt => _reconnectAttempt;

  /// Reconnect automatically when the link drops without [disconnect].
  bool get autoReconnect => _autoReconnect;
  set autoReconnect(bool value) {
    _autoReconnect = value;
    if (!value) cancelReconnect();
  }

  /// Stops reconnecting; the meter stays disconnected until [connect].
  void cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_reconnecting) {
      _reconnecting = false;
      _reconnectAttempt = 0;
      notifyListeners();
    }
  }

  /// What [channel] (0 = CH1) currently measures.
  MeterInput input(int channel) => _inputs[channel];

  /// Whether [channel] may switch to [input]: the shared auxiliary input
  /// (auxiliary voltage, resistance, diode) serves one channel at a time.
  bool canUseInput(int channel, MeterInput input) =>
      !input.usesShared || !_inputs[1 - channel].usesShared;

  /// Full-scale values of [channel]'s ranges, from the meter's tree.
  List<double> ranges(int channel) {
    final tree = _tree;
    return tree == null
        ? const []
        : MeterRanges.forInput(tree, channel, _inputs[channel]);
  }

  bool autoRange(int channel) => _autoRange[channel];
  int rangeIndex(int channel) => _rangeIndex[channel];

  /// Full scale of [channel]'s active range, or null before the handshake.
  double? rangeMax(int channel) {
    final values = ranges(channel);
    if (values.isEmpty) return null;
    return values[_rangeIndex[channel].clamp(0, values.length - 1)];
  }

  /// The value the meter subtracts from [channel] (its "zero").
  double offset(int channel) => _offsets[channel];

  /// The requested sample rate, or null when it follows the inputs.
  int? get sampleRateSetting => _sampleRateSetting;
  int get sampleRateHz => _sampleRates[_sampleRateIndex];
  int get bufferDepth => _bufferDepth;

  /// Significant digits supported by the current rate and buffer depth.
  int get significantDigits => MeterRanges.significantDigits(
    sampleRateIndex: _sampleRateIndex,
    bufferDepth: _bufferDepth,
  );

  /// Time the meter takes to fill one averaging buffer.
  Duration get bufferPeriod =>
      Duration(microseconds: (_bufferDepth * 1e6 / sampleRateHz).round());

  static const _sampleRates = [125, 250, 500, 1000, 2000, 4000, 8000];

  /// Sample rates the meter supports.
  List<int> get sampleRates => _sampleRates;
  int? get sdLogStatus => _sdLogStatus;
  bool get sdCardReady => _sdLogStatus == 0;
  bool get sdLoggingEnabled => _sdLoggingEnabled;
  int get sdLogIntervalSeconds => _sdLogIntervalSeconds;

  String get sdCardStatusLabel {
    final status = _sdLogStatus;
    if (status == null) return 'Status not checked';
    if (status == 0) return 'Ready';
    return 'Card unavailable (status $status)';
  }

  /// Scan for Mooshimeter devices.
  Stream<BleDevice> scan({
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    debugPrint('[BLE] >>> startScan timeout=${timeout.inSeconds}s');
    await UniversalBle.startScan();

    int scanned = 0;
    await for (final bleDevice in UniversalBle.scanStream) {
      scanned++;
      final name = (bleDevice.name ?? '').toLowerCase();
      debugPrint(
        '[BLE]   scanResult #$scanned: name="$name" rssi=${bleDevice.rssi}',
      );

      if (name.contains('mooshimeter') || name.contains('mooshim')) {
        debugPrint('[BLE]   ✓ MATCH: Mooshimeter device');
        yield bleDevice;
      }
    }

    debugPrint('[BLE] >>> stopScan after $scanned results');
    await UniversalBle.stopScan();
  }

  /// Stop scanning.
  Future<void> stopScan() async {
    debugPrint('[BLE] >>> stopScan');
    await UniversalBle.stopScan();
  }

  /// Get devices already connected at the OS level.
  Future<List<BleDevice>> getConnectedDevices() async {
    debugPrint('[BLE] >>> getSystemDevices');
    try {
      final devices = await UniversalBle.getSystemDevices(withServices: []);
      debugPrint(
        '[BLE]   getSystemDevices returned ${devices.length} device(s)',
      );
      for (final d in devices) {
        debugPrint('[BLE]     addr=${d.deviceId} name="${d.name ?? "null"}"');
      }
      return devices;
    } catch (e) {
      debugPrint('[BLE]   getSystemDevices FAILED: $e');
      return [];
    }
  }

  /// Connect to a Mooshimeter device and run the config tree handshake.
  ///
  /// [sampleRate] is the requested rate in Hz, or null to choose it from the
  /// inputs (125 Hz for DC, 4 kHz for AC).
  Future<bool> connect(BleDevice device, {int? sampleRate}) async {
    final deviceId = device.deviceId;
    debugPrint(
      '[BLE] >>> connect START device="${device.name}" addr=$deviceId',
    );
    debugPrint('[BLE]     currentState=${_state.toString().split(".").last}');

    // Guard: idempotent
    if (_state == MmConnectionState.connected) {
      debugPrint('[BLE] >>> connect ALREADY CONNECTED returning true');
      return true;
    }
    if (_state == MmConnectionState.connecting) {
      debugPrint('[BLE] >>> connect ALREADY CONNECTING returning false');
      return false;
    }

    _deviceId = deviceId;
    _lastDevice = device;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setState(MmConnectionState.connecting);

    // Listen for connection state changes. Replace any listener from an
    // earlier attempt, or each link loss would be handled several times.
    await _connectionSub?.cancel();
    _connectionSub = UniversalBle.connectionStream(deviceId).listen((
      isConnected,
    ) {
      debugPrint('[BLE]     connectionStream: $isConnected');
      _transportConnected = isConnected;
      if (!isConnected && _state != MmConnectionState.disconnecting) {
        // The platform can report a disconnect without the user pressing the
        // disconnect button. Stop polling immediately and publish the state
        // transition so clients do not keep rendering the last sample.
        unawaited(_handleTransportDisconnected());
      }
    });

    try {
      debugPrint('[BLE]     calling UniversalBle.connect()');
      // Bounded, so a reconnection attempt to a meter that is out of range
      // fails and retries instead of waiting forever.
      await UniversalBle.connect(
        deviceId,
        timeout: const Duration(seconds: 15),
      );
      // Some Android backends do not emit the initial `true` value on the
      // connection stream. The successful connect call is authoritative;
      // later false events still take the disconnect path above.
      _transportConnected = true;
      debugPrint('[BLE]     UniversalBle.connect() SUCCESS');

      debugPrint('[BLE]     calling UniversalBle.discoverServices()');
      await UniversalBle.discoverServices(deviceId);
      debugPrint('[BLE]     discoverServices SUCCESS');

      // Subscribe to incoming packets (1bc5ffa2 notify)
      await _subscribeToPackets();

      // Run config tree handshake
      debugPrint('[BLE]     starting config tree handshake...');
      final handshakeOk = await _runHandshake();
      if (!handshakeOk) {
        debugPrint('[BLE] >>> handshake FAILED');
        await _cleanupFailedConnection(deviceId);
        _setState(MmConnectionState.disconnected);
        _deviceId = null;
        return false;
      }
      debugPrint('[BLE]     handshake SUCCESS');

      // The VALUE nodes are only updated after the meter's acquisition engine
      // is configured and started.  Polling them before this returns valid
      // protocol frames, but normally just zeroes.
      _sampleRateSetting = sampleRate;
      await _configureMeasurement();

      // A transport loss can occur while the handshake/configuration is in
      // progress. Do not resurrect the connection state after that loss.
      if (!_transportConnected) {
        debugPrint('[BLE] >>> transport disconnected during setup');
        await _cleanupFailedConnection(deviceId);
        _setState(MmConnectionState.disconnected);
        _deviceId = null;
        return false;
      }

      // Start reading channel values
      _startReadingStream();

      // Poll battery
      _battery = await getBatteryVoltage();
      debugPrint('[BLE]     battery voltage = $_battery V');
      notifyListeners();

      // Start periodic reading refresh at 125Hz (default Mooshimeter sample rate)
      _startReadingPolling();
      _startReadingFreshnessWatchdog();

      _setState(MmConnectionState.connected);
      debugPrint('[BLE] <<< connect SUCCESS returning true');
      return true;
    } catch (e, st) {
      debugPrint('[BLE] >>> connect FAILED: $e');
      debugPrint('[BLE]     stack trace: $st');
      await _cleanupFailedConnection(deviceId);
      _setState(MmConnectionState.disconnected);
      _deviceId = null;
      return false;
    }
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    // An explicit disconnect also ends automatic reconnection.
    cancelReconnect();
    if (_state == MmConnectionState.disconnected) return;

    debugPrint('[BLE] >>> disconnect START');
    _setState(MmConnectionState.disconnecting);
    _readingStreamActive = false;

    _connectionSub?.cancel();
    _connectionSub = null;
    _packetSub?.cancel();
    _packetSub = null;
    _readingPollTimer?.cancel();
    _readingPollTimer = null;
    _readingFreshnessTimer?.cancel();
    _readingFreshnessTimer = null;
    _readingPollInProgress = false;

    final devId = _deviceId;
    if (devId != null) {
      try {
        debugPrint('[BLE]     calling UniversalBle.disconnect()');
        await UniversalBle.disconnect(devId);
        debugPrint('[BLE]     UniversalBle.disconnect() SUCCESS');
      } catch (e) {
        debugPrint('[BLE]     UniversalBle.disconnect() FAILED: $e');
      }
    }

    _resetAfterDisconnect();
    _setState(MmConnectionState.disconnected);
    debugPrint('[BLE] <<< disconnect complete');
  }

  Future<void> _handleTransportDisconnected() async {
    _readingStreamActive = false;
    _readingPollTimer?.cancel();
    _readingPollTimer = null;
    _readingFreshnessTimer?.cancel();
    _readingFreshnessTimer = null;
    _readingPollInProgress = false;
    await _packetSub?.cancel();
    _packetSub = null;
    _resetAfterDisconnect();
    if (_state != MmConnectionState.disconnected) {
      _setState(MmConnectionState.disconnected);
    }
    _scheduleReconnect();
  }

  /// Retries the last meter with backoff after an unexpected link loss.
  /// The measurement configuration is kept, so [connect] restores it.
  void _scheduleReconnect() {
    final device = _lastDevice;
    if (!_autoReconnect || device == null || _reconnectTimer != null) return;
    _reconnecting = true;
    final delay =
        reconnectBackoff[_reconnectAttempt.clamp(
          0,
          reconnectBackoff.length - 1,
        )];
    debugPrint(
      '[BLE]     reconnecting in ${delay}s (attempt ${_reconnectAttempt + 1})',
    );
    notifyListeners();
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      _reconnectTimer = null;
      if (!_reconnecting) return;
      _reconnectAttempt++;
      final ok = await connect(device, sampleRate: _sampleRateSetting);
      if (ok) {
        _reconnecting = false;
        _reconnectAttempt = 0;
        notifyListeners();
      } else if (_reconnecting) {
        _scheduleReconnect();
      }
    });
  }

  void _resetAfterDisconnect() {
    _realPower = null;
    _deviceId = null;
    _transportConnected = false;
    _handshakeDone = false;
    _tree = null;
    _serialReassembler.reset();
    _frameDecoder.reset();
    _ch1ValueNodeId = ConfigNode.ch1Value;
    _ch2ValueNodeId = ConfigNode.ch2Value;
    _batteryNodeId = ConfigNode.batV;
    _nextSeqNum = 1;
    _latestReadings = null;
    _lastReadingsAt = null;
    _rssi = -999;
    _battery = 0.0;
    _rangeChangeInProgress = false;
  }

  /// Sets the sample rate in Hz, or null to follow the inputs: 125 Hz for
  /// DC measurements and 4 kHz when either channel measures AC (RMS), as the
  /// original Mooshimeter app does.
  Future<void> setSampleRate(int? rate) async {
    _sampleRateSetting = rate;
    if (_deviceId == null || !_handshakeDone) {
      notifyListeners();
      return;
    }
    await _applySampling();
    notifyListeners();
  }

  /// Selects [input] on [channel] (0 = CH1). Returns false when the other
  /// channel already uses the shared auxiliary input.
  Future<bool> setInput(int channel, MeterInput input) async {
    if (!canUseInput(channel, input)) return false;
    _inputs[channel] = input;
    _rangeIndex[channel] = _initialRange(channel);
    if (_deviceId != null && _handshakeDone) {
      _discardStaleReadings();
      await _applyChannel(channel);
      await _applySampling();
    }
    notifyListeners();
    return true;
  }

  /// Fixes [channel] to range [index] of [ranges], or auto-ranges when
  /// [index] is null.
  Future<void> setRange(int channel, int? index) async {
    _autoRange[channel] = index == null;
    if (index != null) {
      final count = ranges(channel).length;
      _rangeIndex[channel] = count == 0 ? 0 : index.clamp(0, count - 1);
      if (_deviceId != null && _handshakeDone) {
        _discardStaleReadings();
        await _writeRange(channel);
      }
    }
    notifyListeners();
  }

  /// Sets the value the meter subtracts from [channel], for example the lead
  /// resistance in resistance mode. Use 0 to clear it.
  Future<void> setOffset(int channel, double offset) async {
    _offsets[channel] = offset;
    if (_deviceId != null && _handshakeDone) {
      final data = Uint8List(4);
      ByteData.view(data.buffer).setFloat32(0, offset, Endian.little);
      await _writeValue(
        'CH${channel + 1}:OFFSET',
        channel == 0 ? ConfigNode.ch1Offset : ConfigNode.ch2Offset,
        data,
      );
    }
    notifyListeners();
  }

  /// Query the meter's SD-card logger state. LOG:STATUS reports whether the
  /// card is ready; status 0 is the firmware's documented OK value.
  Future<void> refreshSdLogging() async {
    if (_state != MmConnectionState.connected) return;
    final status = await _readNode('LOG:STATUS', ConfigNode.logStatus);
    final on = await _readNode('LOG:ON', ConfigNode.logOn);
    final interval = await _readNode('LOG:INTERVAL', ConfigNode.logInterval);
    if (status != null && status.isNotEmpty) _sdLogStatus = status[0];
    if (on != null && on.isNotEmpty) _sdLoggingEnabled = on[0] != 0;
    if (interval != null && interval.length >= 2) {
      _sdLogIntervalSeconds = ByteData.view(
        interval.buffer,
        interval.offsetInBytes,
      ).getUint16(0, Endian.little);
    }
    notifyListeners();
  }

  Future<void> setSdLoggingEnabled(bool enabled) async {
    await _writeValue(
      'LOG:ON',
      ConfigNode.logOn,
      Uint8List.fromList([enabled ? 1 : 0]),
    );
    _sdLoggingEnabled = enabled;
    notifyListeners();
  }

  Future<void> setSdLogIntervalSeconds(int seconds) async {
    final data = Uint8List(2);
    ByteData.view(data.buffer).setUint16(0, seconds, Endian.little);
    await _writeValue('LOG:INTERVAL', ConfigNode.logInterval, data);
    _sdLogIntervalSeconds = seconds;
    notifyListeners();
  }

  Future<void> _configureMeasurement() async {
    debugPrint('[BLE]     configuring sampling and channel inputs');
    // Two channels cannot share the auxiliary input; a stale combination
    // (for example from an older app version) falls back to the defaults.
    if (_inputs[0].usesShared && _inputs[1].usesShared) {
      _inputs[1] = MeterInput.ch2Default;
    }
    await _applySampling();
    for (final channel in const [0, 1]) {
      _rangeIndex[channel] = _autoRange[channel]
          ? _initialRange(channel)
          : _rangeIndex[channel];
      await _applyChannel(channel);
    }
    for (final channel in const [0, 1]) {
      final value = await _readNode(
        'CH${channel + 1}:OFFSET',
        channel == 0 ? ConfigNode.ch1Offset : ConfigNode.ch2Offset,
      );
      if (value != null && value.length >= 4) {
        _offsets[channel] = ByteData.view(
          value.buffer,
          value.offsetInBytes,
        ).getFloat32(0, Endian.little);
      }
    }
    await _writeChooserByName('SAMPLING:TRIGGER', 'CONTINUOUS');
  }

  /// Auto-ranging starts on the highest range, as bench meters do. Ranging
  /// down jumps straight to the right range in one step, whereas ranging up
  /// from a saturated reading can only climb one range per sample.
  int _initialRange(int channel) => math.max(0, ranges(channel).length - 1);

  Future<void> _applyChannel(int channel) async {
    final input = _inputs[channel];
    final prefix = 'CH${channel + 1}';
    if (input.shared != null) {
      await _writeChooserByName('SHARED', input.shared!);
    }
    await _writeChooserByName('$prefix:MAPPING', input.mapping);
    await _writeChooserByName('$prefix:ANALYSIS', input.analysis);
    await _writeRange(channel);
  }

  Future<void> _writeRange(int channel) async {
    await _writeValue(
      'CH${channel + 1}:RANGE_I',
      channel == 0 ? ConfigNode.ch1RangeI : ConfigNode.ch2RangeI,
      Uint8List.fromList([_rangeIndex[channel]]),
    );
  }

  Future<void> _applySampling() async {
    final rms = _inputs.any((input) => input.isRms);
    final rate = _sampleRateSetting ?? (rms ? 4000 : 125);
    final index = _sampleRates.indexWhere((value) => value >= rate);
    _sampleRateIndex = index < 0 ? _sampleRates.length - 1 : index;
    // RMS needs whole cycles of the waveform: 256 samples at 4 kHz cover
    // several mains periods. DC averages 64 samples.
    _bufferDepth = rms ? 256 : 64;
    await _writeChooserByName('SAMPLING:RATE', '$sampleRateHz');
    await _writeChooserByName('SAMPLING:DEPTH', '$_bufferDepth');
  }

  /// Drops readings converted before a configuration change. The buffer
  /// already filling finishes within one period, but its notification can
  /// arrive a period later over BLE; measured on a V.1, one period let a
  /// stale 1 kΩ-range value through after switching to 10 kΩ.
  void _discardStaleReadings() {
    _discardReadingsUntil = DateTime.now().add(
      bufferPeriod * 2 + const Duration(milliseconds: 100),
    );
    _latestReadings = null;
  }

  Future<void> _writeChooserByName(String path, String option) async {
    final node = _tree?.find(path);
    final index = node?.children.indexWhere((child) => child.name == option);
    if (node == null || node.id == null || index == null || index < 0) {
      throw StateError('Meter tree has no option $option for $path');
    }
    debugPrint('[BLE]     write chooser $path = $option (index $index)');
    await _sendPacket(
      _buildPacket(
        write: true,
        nodeId: node.id!,
        value: Uint8List.fromList([index]),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> _writeValue(
    String path,
    int fallbackNodeId,
    Uint8List value,
  ) async {
    if (_deviceId == null) return;
    await _sendPacket(
      _buildPacket(
        write: true,
        nodeId: _nodeId(path, fallbackNodeId),
        value: value,
      ),
    );
  }

  Future<Uint8List?> _readNode(
    String path,
    int fallbackNodeId, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_deviceId == null) return null;
    final nodeId = _nodeId(path, fallbackNodeId);
    final response = _waitForResponse(nodeId: nodeId, timeout: timeout);
    await _sendPacket(
      _buildPacket(write: false, nodeId: nodeId, value: Uint8List(0)),
    );
    return response;
  }

  /// Get battery voltage via config tree (Node 7 = BAT_V, type Float).
  Future<double> getBatteryVoltage() async {
    final devId = _deviceId;
    if (devId == null || !_handshakeDone) return 0.0;
    try {
      debugPrint('[BLE]     reading BAT_V (Node 7) via config tree');
      final packet = _buildPacket(
        write: false,
        nodeId: _batteryNodeId,
        value: Uint8List(0),
      );
      await _sendPacket(packet);
      // Wait for response — battery value arrives in packet handler
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[BLE]     battery voltage cached = $_battery V');
      return _battery;
    } catch (e) {
      debugPrint('[BLE]     getBatteryVoltage FAILED: $e');
      return 0.0;
    }
  }

  // --- Config tree handshake ---

  /// Perform the config tree handshake:
  /// 1. Read ADMIN:TREE (Node 1, Binary) — gets zlib-compressed tree
  /// 2. Write CRC32 of compressed data to ADMIN:CRC32 (Node 0, U32)
  /// After this, the meter accepts access to the full tree.
  Future<bool> _runHandshake() async {
    final devId = _deviceId;
    if (devId == null) return false;

    try {
      debugPrint('[BLE] >>> _runHandshake START');

      // Step 1: Read ADMIN:TREE (Node 1)
      debugPrint('[BLE]     step 1: read ADMIN:TREE (Node 1)');
      final treePacket = _buildPacket(
        write: false,
        nodeId: ConfigNode.adminTree,
        value: Uint8List(0),
      );
      final treeResponseFuture = _waitForResponse(
        nodeId: ConfigNode.adminTree,
        timeout: const Duration(seconds: 3),
      );
      await _sendPacket(treePacket);

      // Wait for response with tree data
      final treeResponse = await treeResponseFuture;
      if (treeResponse == null) {
        debugPrint('[BLE]     handshake FAILED: no tree response');
        return false;
      }
      if (treeResponse.length < 2) {
        debugPrint('[BLE]     handshake FAILED: truncated tree value');
        return false;
      }
      final treeLength = treeResponse[0] | (treeResponse[1] << 8);
      if (treeResponse.length < treeLength + 2) {
        debugPrint(
          '[BLE]     handshake FAILED: tree length $treeLength exceeds payload',
        );
        return false;
      }
      final compressedTree = Uint8List.fromList(
        treeResponse.sublist(2, treeLength + 2),
      );
      debugPrint(
        '[BLE]     tree response received, compressed length=${compressedTree.length} bytes',
      );
      try {
        _tree = MooshimeterTreeParser.parse(compressedTree);
        _frameDecoder.installTree(_tree!);
        _ch1ValueNodeId = _nodeId('CH1:VALUE', ConfigNode.ch1Value);
        _ch2ValueNodeId = _nodeId('CH2:VALUE', ConfigNode.ch2Value);
        _batteryNodeId = _nodeId('BAT_V', ConfigNode.batV);
        _realPowerNodeId = _nodeId('REAL_PWR', ConfigNode.realPwr);
        debugPrint('[BLE]     runtime config tree parsed');
      } catch (e) {
        debugPrint('[BLE]     handshake FAILED: invalid config tree: $e');
        return false;
      }

      // Step 2: Compute CRC32 and write to ADMIN:CRC32 (Node 0)
      final crc = _Crc32.compute(compressedTree);
      debugPrint(
        '[BLE]     CRC32 = 0x${crc.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      );

      final crcBytes = Uint8List(4);
      crcBytes[0] = crc & 0xFF;
      crcBytes[1] = (crc >> 8) & 0xFF;
      crcBytes[2] = (crc >> 16) & 0xFF;
      crcBytes[3] = (crc >> 24) & 0xFF;

      debugPrint('[BLE]     step 2: write CRC32 to ADMIN:CRC32 (Node 0)');
      final crcPacket = _buildPacket(
        write: true,
        nodeId: ConfigNode.adminCrc32,
        value: crcBytes,
      );
      debugPrint(
        '[BLE]     CRC packet: ${crcPacket.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      final echoResponseFuture = _waitForResponse(
        nodeId: ConfigNode.adminCrc32,
        timeout: const Duration(seconds: 3),
      );
      await _sendPacket(crcPacket);

      // Wait for echo response
      final echoResponse = await echoResponseFuture;
      if (echoResponse == null || echoResponse.length != 4) {
        debugPrint('[BLE]     handshake FAILED: bad CRC echo');
        return false;
      }

      final echoCrc = ByteData.view(
        echoResponse.buffer,
      ).getUint32(0, Endian.little);
      debugPrint(
        '[BLE]     CRC echo = 0x${echoCrc.toRadixString(16).padLeft(8, '0').toUpperCase()} match=${echoCrc == crc}',
      );

      _handshakeDone = true;
      debugPrint('[BLE] <<< _runHandshake SUCCESS');
      return true;
    } catch (e, st) {
      debugPrint('[BLE] >>> _runHandshake FAILED: $e');
      debugPrint('[BLE]     stack trace: $st');
      return false;
    }
  }

  // --- Packet reading stream ---

  /// Subscribe to packet notifications from the meter (1bc5ffa2).
  Future<void> _subscribeToPackets() async {
    final devId = _deviceId;
    if (devId == null) return;

    try {
      debugPrint('[BLE] >>> _subscribeToPackets START');
      _packetSub =
          UniversalBle.characteristicValueStream(
            devId,
            MooshimeterUUIDs.readChar,
          ).listen((data) {
            debugPrint(
              '[BLE]   <<< BLE IN (${data.length} bytes): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
            );
            for (final serialBytes in _serialReassembler.add(data)) {
              for (final frame in _frameDecoder.add(serialBytes)) {
                _handleFrame(frame);
              }
            }
          });
      debugPrint('[BLE]   characteristicValueStream listener added');

      await UniversalBle.subscribeNotifications(
        devId,
        MooshimeterUUIDs.meterService,
        MooshimeterUUIDs.readChar,
      );
      debugPrint('[BLE]   subscribeNotifications() completed');
      debugPrint('[BLE] <<< _subscribeToPackets SUCCESS');
    } catch (e, st) {
      debugPrint('[BLE] >>> _subscribeToPackets FAILED: $e');
      debugPrint('[BLE]     stack trace: $st');
      rethrow;
    }
  }

  Future<void> _cleanupFailedConnection(String deviceId) async {
    _readingPollTimer?.cancel();
    _readingPollTimer = null;
    _readingFreshnessTimer?.cancel();
    _readingFreshnessTimer = null;
    _readingPollInProgress = false;
    await _packetSub?.cancel();
    _packetSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    if (_transportConnected) {
      try {
        await UniversalBle.disconnect(deviceId);
      } catch (e) {
        debugPrint('[BLE]     cleanup disconnect FAILED: $e');
      }
    }
    _transportConnected = false;
  }

  /// Handle a decoded config-tree frame.
  void _handleFrame(MooshimeterFrame frame) {
    debugPrint(
      '[BLE]       nodeId=${frame.nodeId} isWrite=${frame.isWrite} payloadLen=${frame.payload.length}',
    );
    if (frame.isWrite) {
      // Meter is writing to us (echo of our write or spontaneous data)
      _handleMeterWrite(frame.nodeId, frame.payload, 0);
    } else {
      // Meter is responding to our read (or sending unsolicited data)
      _handleMeterRead(frame.nodeId, frame.payload, 0);
    }

    // Signal any pending response
    _completeResponse(frame.nodeId, frame.payload);
  }

  /// Handle meter → app data: readings, battery, errors.
  void _handleMeterRead(int nodeId, Uint8List payload, int seqNum) {
    if (nodeId == _ch1ValueNodeId) {
      if (payload.length >= 4) {
        _ch1Value = ByteData.view(
          payload.buffer,
          payload.offsetInBytes,
        ).getFloat32(0, Endian.little);
        // Continuous sampling sends this value spontaneously. Publish it
        // immediately instead of waiting for a host-driven paired poll.
        _updateReadings();
        debugPrint('[BLE]       CH1.VALUE = $_ch1Value');
      }
      return;
    }
    if (nodeId == _ch2ValueNodeId) {
      if (payload.length >= 4) {
        _ch2Value = ByteData.view(
          payload.buffer,
          payload.offsetInBytes,
        ).getFloat32(0, Endian.little);
        _updateReadings(emitCompleteSample: true);
        debugPrint('[BLE]       CH2.VALUE = $_ch2Value');
        _applyAutorange();
      }
      return;
    }
    if (nodeId == _realPowerNodeId) {
      if (payload.length >= 4) {
        _realPower = ByteData.view(
          payload.buffer,
          payload.offsetInBytes,
        ).getFloat32(0, Endian.little);
      }
      return;
    }
    if (nodeId == _batteryNodeId) {
      if (payload.length >= 4) {
        _battery = ByteData.view(payload.buffer).getFloat32(0, Endian.little);
        debugPrint('[BLE]       BAT_V = $_battery V');
        notifyListeners();
      }
      return;
    }
    switch (nodeId) {
      case ConfigNode.adminCrc32:
        debugPrint(
          '[BLE]       CRC32 echo = 0x${payload.map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}',
        );
        break;

      case ConfigNode.adminDiag:
        debugPrint('[BLE]       DIAGNOSTIC: ${payload.length} bytes (error)');
        break;

      default:
        debugPrint(
          '[BLE]       Node $nodeId: ${payload.length} bytes (unhandled)',
        );
    }
  }

  /// Moves auto-ranging channels to a better range after a complete sample.
  void _applyAutorange() {
    if (_rangeChangeInProgress) return;
    final readings = _latestReadings;
    if (readings == null) return;
    for (final channel in const [0, 1]) {
      if (!_autoRange[channel]) continue;
      final values = ranges(channel);
      if (values.length < 2) continue;
      // The meter subtracts the offset; range on what the input sees.
      final raw = readings.overload(channel)
          ? double.infinity
          : readings.value(channel) + _offsets[channel];
      final target = MeterRanges.autorange(values, _rangeIndex[channel], raw);
      if (target == _rangeIndex[channel]) continue;
      debugPrint(
        '[BLE]     autorange CH${channel + 1}: '
        '${values[_rangeIndex[channel]]} -> ${values[target]}',
      );
      _rangeIndex[channel] = target;
      _rangeChangeInProgress = true;
      _discardStaleReadings();
      unawaited(
        _writeRange(channel).whenComplete(() {
          _rangeChangeInProgress = false;
          notifyListeners();
        }),
      );
      return;
    }
  }

  /// Handle app → meter echo (write command acknowledgment).
  void _handleMeterWrite(int nodeId, Uint8List payload, int seqNum) {
    debugPrint('[BLE]       WRITE echo: Node $nodeId, ${payload.length} bytes');
  }

  /// Update shared readings state and notify listeners.
  void _updateReadings({bool emitCompleteSample = false}) {
    final discardUntil = _discardReadingsUntil;
    if (discardUntil != null && DateTime.now().isBefore(discardUntil)) {
      debugPrint('[BLE]       discarding stale reading after mode change');
      return;
    }
    _discardReadingsUntil = null;
    _latestReadings = DeviceReadings(
      ch1Value: _ch1Value,
      ch2Value: _ch2Value,
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      ch1Overload: _isOverload(0, _ch1Value),
      ch2Overload: _isOverload(1, _ch2Value),
      realPower: _realPower,
    );
    _lastReadingsAt = DateTime.now();
    if (emitCompleteSample) _readingsController.add(_latestReadings!);
    notifyListeners();
  }

  bool _isOverload(int channel, double value) {
    final fullScale = rangeMax(channel);
    if (fullScale == null) return !value.isFinite;
    return MeterRanges.isOverload(value + _offsets[channel], fullScale);
  }

  // --- Packet I/O helpers ---

  /// Build a config tree packet.
  ///
  /// Format: [SeqNum (1 byte)] [NodeID (1 byte, bit 7 = write flag)] [Value bytes...]
  ///   write=true  → NodeID bit 7 set, SeqNum auto-incremented
  ///   write=false → NodeID bit 7 clear, SeqNum auto-incremented
  Uint8List _buildPacket({
    required bool write,
    required int nodeId,
    required Uint8List value,
  }) {
    final seqNum = _nextSeqNum++;
    final nodeIdByte = write ? (nodeId | 0x80) : nodeId;
    final packet = Uint8List(2 + value.length);
    packet[0] = seqNum & 0xFF;
    packet[1] = nodeIdByte;
    if (value.isNotEmpty) {
      packet.setRange(2, 2 + value.length, value);
    }
    return packet;
  }

  /// Send a packet to the meter (write characteristic).
  Future<void> _sendPacket(Uint8List packet) async {
    final devId = _deviceId;
    if (devId == null) return;
    debugPrint(
      '[BLE]     >>> sendPacket: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    await UniversalBle.write(
      devId,
      MooshimeterUUIDs.meterService,
      MooshimeterUUIDs.writeChar,
      packet,
    );
  }

  /// Start a low-frequency keepalive.
  ///
  /// Continuous sampling already emits CH1/CH2 VALUE notifications. Polling
  /// those nodes competes with that stream and can queue stale requests on
  /// the meter. The reference libsigrok driver instead sends a trivial
  /// heartbeat roughly every 15 seconds.
  void _startReadingStream() {
    _readingStreamActive = true;
  }

  void _startReadingPolling() {
    _readingPollTimer?.cancel();
    _readingPollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final devId = _deviceId;
      if (devId == null ||
          !_readingStreamActive ||
          !_handshakeDone ||
          _readingPollInProgress) {
        return;
      }
      _readingPollInProgress = true;
      try {
        debugPrint('[BLE]     sending keepalive...');
        await _sendPacket(
          _buildPacket(
            write: false,
            nodeId: ConfigNode.pcbVersion,
            value: Uint8List(0),
          ),
        );
      } catch (e) {
        debugPrint('[BLE]     reading poll FAILED: $e');
      } finally {
        _readingPollInProgress = false;
      }
    });
  }

  void _startReadingFreshnessWatchdog() {
    _readingFreshnessTimer?.cancel();
    _readingFreshnessTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      if (_latestReadings != null && !hasFreshReadings) {
        debugPrint('[BLE]     readings expired: no fresh sample in 750ms');
        _latestReadings = null;
        notifyListeners();
      }
    });
  }

  /// The id of the node at [path] (for example `CH1:RANGE_I`). Paths must
  /// be complete: a suffix match would also hit option nodes such as
  /// `CH1:MAPPING:SHARED` when looking up `SHARED`.
  int _nodeId(String path, int fallback) => _tree?.find(path)?.id ?? fallback;

  // --- Response waiting ---

  /// Pending response state.
  int? _pendingNodeId;
  Completer<Uint8List?>? _pendingCompleter;

  /// Wait for a response for a specific NodeID with timeout.
  /// Returns the payload bytes or null on timeout.
  Future<Uint8List?> _waitForResponse({
    required int nodeId,
    required Duration timeout,
  }) async {
    final completer = Completer<Uint8List?>();
    _pendingNodeId = nodeId;
    _pendingCompleter = completer;

    try {
      final response = await Future.any([
        completer.future,
        Future.delayed(timeout).then((_) {
          if (!completer.isCompleted) completer.complete(null);
          return null as Uint8List?;
        }),
      ]);
      return response;
    } finally {
      _pendingNodeId = null;
      _pendingCompleter = null;
    }
  }

  /// Complete a pending response.
  void _completeResponse(int nodeId, Uint8List payload) {
    if (_pendingNodeId == nodeId &&
        _pendingCompleter != null &&
        !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(payload);
    }
  }

  // --- State ---

  void _setState(MmConnectionState newState) {
    debugPrint(
      '[BLE]     state: ${_state.toString().split(".").last} → ${newState.toString().split(".").last}',
    );
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('[BLE] >>> dispose START');
    _readingPollTimer?.cancel();
    _readingPollTimer = null;
    _readingFreshnessTimer?.cancel();
    _readingFreshnessTimer = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _packetSub?.cancel();
    _packetSub = null;
    _readingsController.close();
    debugPrint('[BLE] <<< dispose END');
    super.dispose();
  }
}
