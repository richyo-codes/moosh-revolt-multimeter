import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/services/csv_recorder.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

class _Provider extends BleProvider {
  void publish(DeviceReadings readings) => emitReadings(readings);

  @override
  List<double> ranges(int channel) =>
      channel == 0 ? const [10.0] : const [60.0, 600.0];
}

void main() {
  test('records every reading with its mode and unit', () async {
    final dir = await Directory.systemTemp.createTemp('recorder');
    addTearDown(() => dir.delete(recursive: true));
    final provider = _Provider();
    final recorder = CsvRecorder(provider);

    final file = await recorder.start(dir);
    expect(recorder.recording, isTrue);
    provider.publish(
      DeviceReadings(ch1Value: 2.5, ch2Value: 14.2, timestamp: 1000),
    );
    // A mode change mid-recording keeps every row self-describing.
    await provider.setInput(1, ChannelMode.resistance.input);
    provider.publish(
      DeviceReadings(
        ch1Value: 2.6,
        ch2Value: 1265.9,
        timestamp: 1000.5,
        ch2Overload: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(recorder.rows, 2);
    expect(await recorder.stop(), file);

    final lines = await file.readAsLines();
    expect(lines.first, CsvRecorder.header);
    expect(lines[1], endsWith(',current,2.5,A,voltage,14.2,V'));
    expect(lines[2], endsWith(',current,2.6,A,resistance,OL,Ω'));
    expect(lines[2], contains(',1000.500,'));
    expect(recorder.recording, isFalse);
  });
}
