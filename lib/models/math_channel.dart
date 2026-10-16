import 'dart:math' as math;

import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

/// A value derived from both channels, as in the original Mooshimeter app.
enum MathFunction {
  off('Off', ''),
  realPower('Real power', 'W'),
  apparentPower('Apparent power', 'VA'),
  powerFactor('Power factor', ''),
  thermocoupleK('Thermocouple (type K)', '°C');

  const MathFunction(this.label, this.baseUnit);

  final String label;
  final String baseUnit;

  /// The unit shown; the thermocouple follows the temperature preference.
  String get units =>
      this == thermocoupleK ? DisplayPreferences.temperature.symbol : baseUnit;

  bool get _power =>
      this == realPower || this == apparentPower || this == powerFactor;

  /// What the channels must measure, in words, for the hint on the card.
  String get requirement => switch (this) {
    off => '',
    thermocoupleK =>
      'Needs a type-K thermocouple on the auxiliary input (one channel on '
          'Aux voltage DC) and Temperature on the other channel.',
    _ => 'Needs CH1 on current and CH2 on voltage (both DC or both AC).',
  };

  /// Whether the present channel modes allow this function.
  bool isValid(ChannelMode ch1, ChannelMode ch2) {
    if (_power) {
      final current =
          ch1 == ChannelMode.current || ch1 == ChannelMode.currentAc;
      final voltage =
          ch2 == ChannelMode.voltage || ch2 == ChannelMode.voltageAc;
      return current && voltage;
    }
    if (this == thermocoupleK) {
      return (ch1 == ChannelMode.auxiliaryVoltageDc &&
              ch2 == ChannelMode.internalTemperature) ||
          (ch2 == ChannelMode.auxiliaryVoltageDc &&
              ch1 == ChannelMode.internalTemperature);
    }
    return false;
  }

  /// Channel modes that make this function valid, keeping AC if either
  /// channel already measures AC.
  (ChannelMode, ChannelMode) setupFor(ChannelMode ch1, ChannelMode ch2) {
    if (this == thermocoupleK) {
      return (ChannelMode.auxiliaryVoltageDc, ChannelMode.internalTemperature);
    }
    final ac = ch1.input.isRms || ch2.input.isRms;
    return ac
        ? (ChannelMode.currentAc, ChannelMode.voltageAc)
        : (ChannelMode.current, ChannelMode.voltage);
  }

  /// The value for [readings], or NaN when an input is overloaded or the
  /// channels do not allow this function.
  double compute(
    BleProvider provider,
    DeviceReadings readings, {
    TemperatureUnit? temperatureUnit,
  }) {
    final ch1Mode = provider.mode(0);
    final ch2Mode = provider.mode(1);
    if (!isValid(ch1Mode, ch2Mode)) return double.nan;
    if (this == thermocoupleK) {
      // Cold-junction compensation the simple way the original app did it:
      // the meter's own temperature plus the thermocouple's difference.
      final auxChannel = ch1Mode == ChannelMode.auxiliaryVoltageDc ? 0 : 1;
      if (readings.overload(0) || readings.overload(1)) return double.nan;
      final volts = readings.value(auxChannel);
      final coldJunction = TemperatureUnit.celsius.fromKelvin(
        readings.value(1 - auxChannel),
      );
      final celsius = coldJunction + typeKDeltaCelsius(volts);
      return (temperatureUnit ?? DisplayPreferences.temperature).fromKelvin(
        celsius + 273.15,
      );
    }
    final current = provider.displayValue(readings, 0);
    final voltage = provider.displayValue(readings, 1);
    if (current.isNaN || voltage.isNaN) return double.nan;
    final apparent = current * voltage;
    final real = readings.realPower;
    return switch (this) {
      realPower => real ?? double.nan,
      apparentPower => apparent,
      powerFactor =>
        real == null || apparent.abs() < 1e-9 ? double.nan : real / apparent,
      _ => double.nan,
    };
  }

  /// Full scale used to format the value like a meter reading.
  double fullScaleFor(BleProvider provider) => switch (this) {
    powerFactor => 1,
    thermocoupleK => 500,
    _ => (provider.rangeMax(0) ?? 10) * (provider.rangeMax(1) ?? 600),
  };
}

/// Temperature difference for a type-K thermocouple voltage, from the
/// ITS-90 inverse polynomial (valid 0–500 °C, 0–20.644 mV).
double typeKDeltaCelsius(double volts) {
  const coefficients = [
    0.0,
    2.508355e-2,
    7.860106e-8,
    -2.503131e-10,
    8.315270e-14,
    -1.228034e-17,
    9.804036e-22,
    -4.413030e-26,
    1.057734e-30,
    -1.052755e-35,
  ];
  final microvolts = volts * 1e6;
  var result = 0.0;
  for (var i = 0; i < coefficients.length; i++) {
    result += coefficients[i] * math.pow(microvolts, i);
  }
  return result;
}
