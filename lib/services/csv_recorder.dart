import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

/// Records every reading the meter sends to a CSV file, for sessions of any
/// length.
///
/// Unlike the chart snapshot, it takes each complete CH1/CH2 sample from
/// the provider's stream, so nothing is thinned or limited to the chart's
/// history window. Every row names its mode and unit, so changing a
/// channel's measurement mid-recording keeps the file consistent. It keeps
/// recording across reconnects, which simply leave a gap in time.
class CsvRecorder extends ChangeNotifier {
  CsvRecorder(this._provider);

  final BleProvider _provider;
  IOSink? _sink;
  File? _file;
  DateTime? _startedAt;
  int _rows = 0;
  StreamSubscription<DeviceReadings>? _subscription;
  Timer? _flushTimer;

  static const header =
      'timestamp_iso8601,unix_seconds,'
      'ch1_mode,ch1_value,ch1_unit,ch2_mode,ch2_value,ch2_unit';

  bool get recording => _sink != null;
  File? get file => _file;
  DateTime? get startedAt => _startedAt;
  int get rows => _rows;

  /// Starts a new recording in [directory] and returns its file.
  Future<File> start(Directory directory) async {
    if (recording) return _file!;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/mooshrevolt_recording_$stamp.csv');
    final sink = file.openWrite()..writeln(header);
    _file = file;
    _sink = sink;
    _startedAt = DateTime.now();
    _rows = 0;
    _subscription = _provider.readings.listen((readings) {
      sink.writeln(csvRow(_provider, readings));
      _rows++;
      notifyListeners();
    });
    // Flush regularly so a crash or power loss costs at most a few seconds.
    _flushTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(sink.flush()),
    );
    notifyListeners();
    return file;
  }

  /// Stops recording and returns the finished file.
  Future<File?> stop() async {
    final sink = _sink;
    if (sink == null) return null;
    _sink = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await sink.flush();
    await sink.close();
    notifyListeners();
    return _file;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}

/// One CSV row for [readings]: each channel's mode, value in its display
/// unit (or OL) and unit.
String csvRow(BleProvider provider, DeviceReadings readings) {
  final time = DateTime.fromMillisecondsSinceEpoch(
    (readings.timestamp * 1000).round(),
  );
  final fields = [
    time.toIso8601String(),
    readings.timestamp.toStringAsFixed(3),
  ];
  for (final channel in const [0, 1]) {
    final mode = provider.mode(channel);
    final value = provider.displayValue(readings, channel);
    fields
      ..add(mode.name)
      ..add(value.isNaN ? 'OL' : '$value')
      ..add(mode.units);
  }
  return fields.join(',');
}
