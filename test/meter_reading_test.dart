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

  test('reports each channel mode in the unit the firmware measures', () {
    expect(ChannelMode.resistance.unitsFor(0), 'Ω');
    expect(ChannelMode.diode.unitsFor(0), 'V');
    expect(ChannelMode.auxiliaryVoltageDc.unitsFor(0), 'V');
    expect(ChannelMode.current.unitsFor(0), 'A');
    expect(ChannelMode.currentAc.unitsFor(0), 'A');
    expect(ChannelMode.voltage.unitsFor(1), 'V');
    expect(ChannelMode.internalTemperature.unitsFor(1), '°C');
  });

  test('formats resistance with ohm prefixes like a bench meter', () {
    final reading = MeterReading(
      timestamp: 0,
      value: 4700,
      units: ChannelMode.resistance.unitsFor(0),
      digits: 4,
      max: 1000,
    );
    expect(reading.formatted, ' 4.700kΩ');
    expect(DisplayUnit.choicesFor('Ω'), [
      DisplayUnit.auto,
      DisplayUnit.base,
      DisplayUnit.kilo,
      DisplayUnit.mega,
    ]);
    expect(DisplayUnit.mega.label('Ω'), 'MΩ');
    expect(DisplayUnit.choicesFor('A'), isNot(contains(DisplayUnit.mega)));
  });

  test('counts shorted probes with a negative zero offset as continuity', () {
    expect(hasContinuity(-1.3), isTrue);
    expect(hasContinuity(0.2), isTrue);
    expect(hasContinuity(49.9), isTrue);
    expect(hasContinuity(50), isFalse);
    // Open circuit saturates at about +1266 Ω on the 1 kΩ range.
    expect(hasContinuity(1265.95), isFalse);
    // Negative saturation is a front-end artefact, not a short.
    expect(hasContinuity(-977.7), isFalse);
    expect(hasContinuity(double.nan), isFalse);
  });
}
