import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluez/bluez.dart';
import 'package:mooshimeter_ble/mooshimeter_protocol.dart';

/// Pure-Dart Linux/BlueZ Mooshimeter CSV logger.
Future<void> main(List<String> arguments) async {
  final options = _LoggerOptions.parse(arguments);
  if (options.showHelp) return stdout.write(_LoggerOptions.usage);

  final client = BlueZClient();
  _MooshimeterCliConnection? meter;
  IOSink? ownedFile;
  var rows = 0;
  var stopping = false;

  Future<void> stop({int exitCode = 0}) async {
    if (stopping) return;
    stopping = true;
    await meter?.close();
    await ownedFile?.flush();
    await ownedFile?.close();
    await client.close();
    stderr.writeln('Logged $rows sample${rows == 1 ? '' : 's'}.');
    if (exitCode != 0) exit(exitCode);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(stop()));
  ProcessSignal.sigterm.watch().listen((_) => unawaited(stop()));
  try {
    await client.connect();
    final device = await _selectDevice(client, options);
    if (device == null) {
      stderr.writeln(
        'No Mooshimeter found. Check BlueZ/pairing or pass --device ADDRESS.',
      );
      await stop(exitCode: 2);
      return;
    }
    meter = _MooshimeterCliConnection(device, options.sampleRate);
    stderr.writeln(
      'Connecting to ${device.name.isEmpty ? 'Mooshimeter' : device.name} (${device.address})…',
    );
    await meter.connect();

    final IOSink sink = options.outputPath == '-'
        ? stdout
        : File(options.outputPath).openWrite(mode: FileMode.write);
    if (options.outputPath != '-') ownedFile = sink;
    sink.writeln(_csvHeader(options.channels));
    meter.readings.listen((reading) {
      sink.writeln(_csvRow(reading, options.channels));
      rows++;
    });
    stderr.writeln(
      'Logging ${options.channels.label} at ${options.sampleRate} Hz to ${options.outputPath}. Press Ctrl-C to stop.',
    );

    if (options.duration case final duration?) {
      await Future<void>.delayed(duration);
      await stop();
      return;
    }
    while (!stopping) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  } catch (error, stackTrace) {
    stderr.writeln('Logger failed: $error\n$stackTrace');
    await stop(exitCode: 1);
  }
}

Future<BlueZDevice?> _selectDevice(
  BlueZClient client,
  _LoggerOptions options,
) async {
  final requested = options.deviceAddress?.toLowerCase();
  bool matches(BlueZDevice device) => requested != null
      ? device.address.toLowerCase() == requested
      : device.name.toLowerCase().contains('mooshim') ||
            device.alias.toLowerCase().contains('mooshim');
  for (final device in client.devices) {
    if (matches(device)) return device;
  }
  final adapter = client.adapters
      .where((adapter) => adapter.powered)
      .firstOrNull;
  if (adapter == null) throw StateError('No powered Bluetooth adapter found.');
  stderr.writeln(
    'Scanning for ${requested ?? 'a Mooshimeter'} for ${options.scanTimeout.inSeconds}s…',
  );
  final result = Completer<BlueZDevice?>();
  final subscription = client.deviceAdded.listen((device) {
    if (matches(device) && !result.isCompleted) result.complete(device);
  });
  try {
    await adapter.setDiscoveryFilter(transport: 'le');
    await adapter.startDiscovery();
    return await result.future.timeout(
      options.scanTimeout,
      onTimeout: () => null,
    );
  } finally {
    await adapter.stopDiscovery();
    await subscription.cancel();
  }
}

class _MooshimeterCliConnection {
  _MooshimeterCliConnection(this.device, this.sampleRate);

  static const serviceUuid = '1bc5ffa0-0200-62ab-e411-f254e005dbd4';
  static const writeUuid = '1bc5ffa1-0200-62ab-e411-f254e005dbd4';
  static const notifyUuid = '1bc5ffa2-0200-62ab-e411-f254e005dbd4';
  final BlueZDevice device;
  final int sampleRate;
  final _serial = MooshimeterSerialReassembler();
  final _decoder = MooshimeterFrameDecoder();
  final _readings = StreamController<_CliReading>.broadcast();
  final Map<int, Completer<Uint8List>> _responses = {};
  StreamSubscription? _notificationSubscription;
  Timer? _pollTimer;
  BlueZGattCharacteristic? _write;
  BlueZGattCharacteristic? _notify;
  MooshimeterNode? _tree;
  int _sequence = 1;
  int _ch1Node = 25;
  int _ch2Node = 33;
  double _ch1 = 0;
  double _ch2 = 0;

  Stream<_CliReading> get readings => _readings.stream;

  Future<void> connect() async {
    if (!device.connected) await device.connect();
    if (!device.servicesResolved) {
      await device.propertiesChanged
          .firstWhere(
            (properties) =>
                properties.contains('ServicesResolved') || !device.connected,
          )
          .timeout(const Duration(seconds: 15));
    }
    if (!device.connected || device.gattServices.isEmpty) {
      throw StateError('BlueZ did not resolve GATT services.');
    }
    final service = device.gattServices.firstWhere(
      (candidate) => candidate.uuid.toString().toLowerCase() == serviceUuid,
    );
    _write = service.characteristics.firstWhere(
      (candidate) => candidate.uuid.toString().toLowerCase() == writeUuid,
    );
    _notify = service.characteristics.firstWhere(
      (candidate) => candidate.uuid.toString().toLowerCase() == notifyUuid,
    );
    _notificationSubscription = _notify!.propertiesChanged.listen((properties) {
      if (!properties.contains('Value')) return;
      _onNotification(Uint8List.fromList(_notify!.value));
    });
    await _notify!.startNotify();
    await _handshake();
    await _configure();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> _handshake() async {
    final treePayload = await _readNode(1);
    final treeLength = treePayload[0] | (treePayload[1] << 8);
    final compressed = Uint8List.fromList(
      treePayload.sublist(2, treeLength + 2),
    );
    _tree = MooshimeterTreeParser.parse(compressed);
    _decoder.installTree(_tree!);
    _ch1Node = _nodeId('CH1:VALUE', 25);
    _ch2Node = _nodeId('CH2:VALUE', 33);
    await _writeNode(0, _u32(_crc32(compressed)));
  }

  Future<void> _configure() async {
    const rates = [125, 250, 500, 1000, 2000, 4000, 8000];
    final rateIndex = rates.indexWhere((rate) => rate >= sampleRate);
    await _writeChooser(
      _nodeId('SAMPLING:RATE', 9),
      rateIndex < 0 ? rates.length - 1 : rateIndex,
    );
    await _writeChooser(_nodeId('SAMPLING:DEPTH', 10), 1); // 64 samples
    await _writeChooser(_nodeId('CH1:ANALYSIS', 24), 0); // CH1 mean/DC
    await _writeChooser(_nodeId('CH2:ANALYSIS', 32), 0); // CH2 mean/DC
    await _writeChooser(_nodeId('CH2:MAPPING', 30), 0); // CH2 voltage
    await _writeChooser(_nodeId('CH1:RANGE_I', 23), 0); // CH1 10 A
    await _writeChooser(_nodeId('CH2:RANGE_I', 31), 0); // CH2 60 V
    await _writeChooser(_nodeId('SAMPLING:TRIGGER', 11), 2); // continuous
  }

  Future<void> _poll() async {
    try {
      await _send(_ch1Node, const []);
      await _send(_ch2Node, const []);
    } catch (error) {
      stderr.writeln('Polling failed: $error');
    }
  }

  Future<Uint8List> _readNode(int nodeId) async {
    final response = _waitFor(nodeId);
    await _send(nodeId, const []);
    return response;
  }

  Future<void> _writeChooser(int nodeId, int value) =>
      _writeNode(nodeId, [value]);

  Future<void> _writeNode(int nodeId, Iterable<int> payload) async {
    final response = _waitFor(nodeId);
    await _send(nodeId | 0x80, payload);
    await response;
  }

  Future<Uint8List> _waitFor(int nodeId) {
    final completer = Completer<Uint8List>();
    _responses[nodeId] = completer;
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _responses.remove(nodeId);
        throw TimeoutException('Timed out waiting for node $nodeId');
      },
    );
  }

  Future<void> _send(int nodeByte, Iterable<int> payload) => _write!.writeValue(
    [_sequence++ & 0xff, nodeByte, ...payload],
    type: BlueZGattCharacteristicWriteType.request,
  );

  void _onNotification(Uint8List packet) {
    for (final serial in _serial.add(packet)) {
      for (final frame in _decoder.add(serial)) {
        _responses.remove(frame.nodeId)?.complete(frame.payload);
        if (frame.nodeId == _ch1Node && frame.payload.length >= 4) {
          _ch1 = ByteData.view(
            frame.payload.buffer,
            frame.payload.offsetInBytes,
          ).getFloat32(0, Endian.little);
        } else if (frame.nodeId == _ch2Node && frame.payload.length >= 4) {
          _ch2 = ByteData.view(
            frame.payload.buffer,
            frame.payload.offsetInBytes,
          ).getFloat32(0, Endian.little);
          _readings.add(_CliReading(DateTime.now().toUtc(), _ch1, _ch2));
        }
      }
    }
  }

  Future<void> close() async {
    _pollTimer?.cancel();
    await _notificationSubscription?.cancel();
    if (_notify?.notifying == true) await _notify?.stopNotify();
    if (device.connected) await device.disconnect();
    await _readings.close();
  }

  int _nodeId(String path, int fallback) {
    MooshimeterNode? match;
    void visit(MooshimeterNode node) {
      if (node.path == path || node.path.endsWith(':$path')) match = node;
      for (final child in node.children) {
        visit(child);
      }
    }

    final tree = _tree;
    if (tree != null) visit(tree);
    return match?.id ?? fallback;
  }
}

class _CliReading {
  const _CliReading(this.time, this.ch1, this.ch2);
  final DateTime time;
  final double ch1;
  final double ch2;
}

int _crc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (crc & 1 == 1 ? 0xedb88320 : 0);
    }
  }
  return crc ^ 0xffffffff;
}

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

String _csvHeader(_ChannelSelection channels) => switch (channels) {
  _ChannelSelection.ch1 => 'timestamp_iso8601,unix_seconds,ch1_a',
  _ChannelSelection.ch2 => 'timestamp_iso8601,unix_seconds,ch2_v',
  _ChannelSelection.both => 'timestamp_iso8601,unix_seconds,ch1_a,ch2_v',
};

String _csvRow(_CliReading reading, _ChannelSelection channels) {
  final fields = [
    reading.time.toIso8601String(),
    (reading.time.millisecondsSinceEpoch / 1000).toStringAsFixed(3),
  ];
  switch (channels) {
    case _ChannelSelection.ch1:
      fields.add(reading.ch1.toString());
    case _ChannelSelection.ch2:
      fields.add(reading.ch2.toString());
    case _ChannelSelection.both:
      fields
        ..add(reading.ch1.toString())
        ..add(reading.ch2.toString());
  }
  return fields.join(',');
}

enum _ChannelSelection {
  ch1('channel 1'),
  ch2('channel 2'),
  both('both channels');

  const _ChannelSelection(this.label);
  final String label;
}

class _LoggerOptions {
  const _LoggerOptions({
    required this.deviceAddress,
    required this.channels,
    required this.outputPath,
    required this.sampleRate,
    required this.scanTimeout,
    required this.duration,
    required this.showHelp,
  });
  final String? deviceAddress;
  final _ChannelSelection channels;
  final String outputPath;
  final int sampleRate;
  final Duration scanTimeout;
  final Duration? duration;
  final bool showHelp;
  static const usage = '''Mooshimeter CSV logger (Linux / BlueZ)

Usage: dart run tool/mooshimeter_log.dart [options]

Options:
  --device ADDRESS       BLE/MAC address; scan selects the first meter when omitted
  --channel ch1|ch2|both Channels to write (default: both)
  --output PATH          CSV destination, or - for stdout (default: mooshimeter.csv)
  --rate HZ              Meter sample rate: 125, 250, 500, 1000, 2000, 4000, 8000
  --scan-timeout SEC     Scan timeout in seconds (default: 10)
  --duration SEC         Stop automatically after this duration
  --help, -h             Show this help
''';
  factory _LoggerOptions.parse(List<String> arguments) {
    String? device;
    var channels = _ChannelSelection.both;
    var output = 'mooshimeter.csv';
    var rate = 125;
    var timeout = const Duration(seconds: 10);
    Duration? duration;
    var help = false;
    for (var i = 0; i < arguments.length; i++) {
      final option = arguments[i];
      if (option == '--help' || option == '-h') {
        help = true;
        continue;
      }
      if (++i >= arguments.length) {
        throw FormatException('$option requires a value.');
      }
      final value = arguments[i];
      switch (option) {
        case '--device':
          device = value;
        case '--channel':
          channels = switch (value) {
            'ch1' => _ChannelSelection.ch1,
            'ch2' => _ChannelSelection.ch2,
            'both' => _ChannelSelection.both,
            _ => throw FormatException('--channel must be ch1, ch2, or both.'),
          };
        case '--output':
          output = value;
        case '--rate':
          rate = int.parse(value);
        case '--scan-timeout':
          timeout = Duration(seconds: int.parse(value));
        case '--duration':
          duration = Duration(seconds: int.parse(value));
        default:
          throw FormatException('Unknown option: $option');
      }
    }
    if (!const {125, 250, 500, 1000, 2000, 4000, 8000}.contains(rate)) {
      throw FormatException('Unsupported --rate $rate.');
    }
    return _LoggerOptions(
      deviceAddress: device,
      channels: channels,
      outputPath: output,
      sampleRate: rate,
      scanTimeout: timeout,
      duration: duration,
      showHelp: help,
    );
  }
}
