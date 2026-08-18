import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';

void main() {
  test('formats ordinary volts without an SI prefix', () {
    final scale = SiScale.forValue(1.2);
    expect(scale.multiplier, 1);
    expect(scale.prefix, '');
    expect(
      MeterReading(
        timestamp: 0,
        value: 1.2,
        units: 'V',
        digits: 4,
        max: 60,
      ).formatted,
      ' 1.200V',
    );
  });

  test('formats small voltages with the correct SI prefix', () {
    final micro = SiScale.forValue(0.0000732756);
    expect(0.0000732756 * micro.multiplier, closeTo(73.2756, 0.0001));
    expect(micro.prefix, 'μ');

    final nano = SiScale.forValue(4e-9);
    expect(4e-9 * nano.multiplier, closeTo(4, 0.0001));
    expect(nano.prefix, 'n');
  });

  test('uses the physical Mooshimeter channel units', () {
    expect(Channel.ch1.units, 'A');
    expect(Channel.ch2.units, 'V');
  });
}
