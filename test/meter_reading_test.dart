import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';

void main() {
  test('picks SI prefixes for loose values', () {
    final micro = SiScale.forValue(0.0000732756);
    expect(0.0000732756 * micro.multiplier, closeTo(73.2756, 0.0001));
    expect(micro.prefix, 'μ');
    expect(SiScale.forValue(4e-9).prefix, 'n');
  });

  test('picks the bench-meter prefix for a range', () {
    expect(SiScale.forRange(1000).prefix, '');
    expect(SiScale.forRange(1e4).prefix, 'k');
    expect(SiScale.forRange(1e6).prefix, 'k');
    expect(SiScale.forRange(600).prefix, '');
    expect(SiScale.forRange(60).prefix, '');
    expect(SiScale.forRange(1e7).prefix, 'M');
    expect(SiScale.forRange(0.1).prefix, 'm');
  });

  test('fixes the decimal point by range and resolution', () {
    const volts = ReadingFormat(
      units: 'V',
      fullScale: 60,
      significantDigits: 6,
    );
    expect(volts.format(14.24), '14.2400 V');
    const ohms = ReadingFormat(
      units: 'Ω',
      fullScale: 1e4,
      significantDigits: 5,
    );
    expect(ohms.format(4700), '4.700 kΩ');
    // The prefix follows the range, not the value, so digits stay put.
    expect(ohms.format(12), '0.012 kΩ');
    const kelvin = ReadingFormat(
      units: '°C',
      fullScale: 76.85,
      significantDigits: 6,
    );
    expect(kelvin.format(25.123), '25.12 °C');
  });

  test('reports each channel mode in the unit the firmware measures', () {
    expect(ChannelMode.resistance.units, 'Ω');
    expect(ChannelMode.diode.units, 'V');
    expect(ChannelMode.auxiliaryVoltageDc.units, 'V');
    expect(ChannelMode.current.units, 'A');
    expect(ChannelMode.currentAc.units, 'A');
    expect(ChannelMode.voltage.units, 'V');
    expect(ChannelMode.internalTemperature.units, '°C');
    expect(
      ChannelMode.internalTemperature.toDisplay(298.15),
      closeTo(25, 1e-9),
    );
  });

  test('maps modes onto the meter\'s named inputs', () {
    expect(ChannelMode.diode.input.shared, 'DIODE');
    expect(ChannelMode.diode.input.mapping, 'SHARED');
    expect(ChannelMode.currentAc.input.mapping, 'CURRENT');
    expect(ChannelMode.currentAc.input.analysis, 'RMS');
    expect(ChannelMode.internalTemperature.input.mapping, 'TEMP');
    expect(
      ChannelMode.fromInput(1, ChannelMode.resistance.input),
      ChannelMode.resistance,
    );
    expect(ChannelMode.forChannel(0), isNot(contains(ChannelMode.voltage)));
    expect(ChannelMode.forChannel(1), contains(ChannelMode.diode));
  });

  test('flags resistance driven by an external voltage', () {
    expect(ChannelMode.resistance.isImplausible(-1.3, 1000), isFalse);
    expect(ChannelMode.resistance.isImplausible(-977.7, 1000), isTrue);
    expect(ChannelMode.voltage.isImplausible(-50, 60), isFalse);
  });

  test('offers ohm prefixes like a bench meter', () {
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
    expect(hasContinuity(1265.95), isFalse);
    expect(hasContinuity(double.nan), isFalse);
  });

  test('shows internal temperature in the chosen unit', () {
    addTearDown(() => DisplayPreferences.temperature = TemperatureUnit.celsius);
    expect(
      ChannelMode.internalTemperature.toDisplay(298.15),
      closeTo(25, 1e-9),
    );
    DisplayPreferences.temperature = TemperatureUnit.fahrenheit;
    expect(ChannelMode.internalTemperature.units, '°F');
    expect(
      ChannelMode.internalTemperature.toDisplay(298.15),
      closeTo(77, 1e-9),
    );
    expect(ChannelMode.voltage.toDisplay(12), 12);
  });

  test('beeps for continuity and for a shorted diode', () {
    expect(ChannelMode.resistance.beepsAt(-1.2), isTrue);
    expect(ChannelMode.resistance.beepsAt(470), isFalse);
    expect(ChannelMode.diode.beepsAt(0.04), isTrue);
    expect(ChannelMode.diode.beepsAt(0.62), isFalse);
    expect(ChannelMode.diode.beepsAt(double.nan), isFalse);
    expect(ChannelMode.voltage.beepsAt(0), isFalse);
    expect(ChannelMode.diode.hasTone, isTrue);
    expect(ChannelMode.current.hasTone, isFalse);
  });
}
