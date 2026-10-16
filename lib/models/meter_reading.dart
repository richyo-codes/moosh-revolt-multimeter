import 'dart:math' as math;

import 'package:mooshimeter_ble/mooshimeter_ble.dart';

/// Resistance below which a probe pair counts as continuous, matching the
/// beep threshold of typical bench meters (Fluke uses 25–70 Ω).
const continuityThresholdOhms = 50.0;

/// Whether a resistance reading indicates continuity.
///
/// Shorted probes read slightly negative (about −1 Ω on the 1 kΩ range)
/// because the meter's zero offset exceeds the lead resistance, so the test
/// is on magnitude.
bool hasContinuity(double ohms) =>
    ohms.isFinite && ohms.abs() < continuityThresholdOhms;

/// What a channel measures, mapped onto the meter's named inputs.
enum ChannelMode {
  current('Current DC', MeterInput(mapping: 'CURRENT')),
  currentAc('Current AC', MeterInput(mapping: 'CURRENT', analysis: 'RMS')),
  voltage('Voltage DC', MeterInput(mapping: 'VOLTAGE')),
  voltageAc('Voltage AC', MeterInput(mapping: 'VOLTAGE', analysis: 'RMS')),
  internalTemperature('Internal Temperature', MeterInput(mapping: 'TEMP')),
  auxiliaryVoltageDc(
    'Auxiliary Voltage DC',
    MeterInput(mapping: 'SHARED', shared: 'AUX_V'),
  ),
  auxiliaryVoltageAc(
    'Auxiliary Voltage AC',
    MeterInput(mapping: 'SHARED', shared: 'AUX_V', analysis: 'RMS'),
  ),
  resistance('Resistance', MeterInput(mapping: 'SHARED', shared: 'RESISTANCE')),
  diode('Diode Drop', MeterInput(mapping: 'SHARED', shared: 'DIODE'));

  const ChannelMode(this.label, this.input);

  final String label;
  final MeterInput input;

  /// Modes each channel offers, as in the original Mooshimeter app. CH1's
  /// dedicated input is the current shunt, CH2's is the voltage divider; the
  /// shared auxiliary modes are available on either, one channel at a time.
  static List<ChannelMode> forChannel(int channel) => [
    if (channel == 0) ...[current, currentAc] else ...[voltage, voltageAc],
    internalTemperature,
    auxiliaryVoltageDc,
    auxiliaryVoltageAc,
    resistance,
    diode,
  ];

  /// The mode matching what the meter reports for [channel].
  static ChannelMode fromInput(int channel, MeterInput input) =>
      forChannel(channel).firstWhere(
        (mode) => mode.input == input,
        orElse: () => channel == 0 ? current : voltage,
      );

  bool get usesSharedInput => input.usesShared;

  /// The unit shown to the user. The meter reports temperature in kelvin.
  String get units => switch (this) {
    resistance => 'Ω',
    internalTemperature => '°C',
    current || currentAc => 'A',
    _ => 'V',
  };

  /// Converts a value in the meter's native unit to [units].
  double toDisplay(double native) =>
      this == internalTemperature ? native - 273.15 : native;

  /// Whether a reading in [units] is invalid although the input is not
  /// saturated. A resistance well below zero means an external voltage is
  /// driving the probes (the meter sees about −60 V on CH2 at the same
  /// moments), so it is not a resistance.
  bool isImplausible(double value, double fullScale) =>
      this == resistance && value < -0.05 * fullScale;
}

/// Display-level view of the provider's channels, shared by the meter
/// screen and the metrics exporter so both apply the same rules.
extension MeterChannels on BleProvider {
  ChannelMode mode(int channel) =>
      ChannelMode.fromInput(channel, input(channel));

  /// Full scale of [channel]'s active range in its display unit.
  double? displayFullScale(int channel) {
    final fullScale = rangeMax(channel);
    return fullScale == null ? null : mode(channel).toDisplay(fullScale);
  }

  /// [channel]'s reading in its display unit, or NaN when it is not a
  /// measurement (input saturated, or a resistance driven by a voltage).
  double displayValue(DeviceReadings readings, int channel) {
    if (readings.overload(channel)) return double.nan;
    final channelMode = mode(channel);
    final value = channelMode.toDisplay(readings.value(channel));
    final fullScale = rangeMax(channel);
    if (fullScale != null && channelMode.isImplausible(value, fullScale)) {
      return double.nan;
    }
    return value;
  }
}

class SiScale {
  const SiScale(this.multiplier, this.prefix);

  final double multiplier;
  final String prefix;

  factory SiScale.forValue(double value) {
    final magnitude = value.abs();
    if (magnitude == 0 || magnitude >= 1 && magnitude < 1000) {
      return const SiScale(1, '');
    }
    if (magnitude >= 1e9) return const SiScale(1e-9, 'G');
    if (magnitude >= 1e6) return const SiScale(1e-6, 'M');
    if (magnitude >= 1e3) return const SiScale(1e-3, 'k');
    if (magnitude >= 1e-3) return const SiScale(1e3, 'm');
    if (magnitude >= 1e-6) return const SiScale(1e6, 'μ');
    if (magnitude >= 1e-9) return const SiScale(1e9, 'n');
    return const SiScale(1e12, 'p');
  }

  /// The prefix a bench meter uses for a range of [fullScale]: the largest
  /// that keeps 1–3 integer digits, so "10 kΩ" reads in kΩ and "100 mV" in
  /// mV.
  factory SiScale.forRange(double fullScale) {
    // A "1000" range reads up to 1199.99, so it stays in the base unit;
    // the prefix steps up only past three integer digits.
    final exponent = (math.log(fullScale.abs()) / math.ln10 - 1e-9).floor();
    final group = (exponent / 3).floor().clamp(-4, 3);
    const prefixes = {
      -4: 'p',
      -3: 'n',
      -2: 'μ',
      -1: 'm',
      0: '',
      1: 'k',
      2: 'M',
      3: 'G',
    };
    return SiScale(math.pow(10, -3 * group).toDouble(), prefixes[group]!);
  }
}

enum DisplayUnit {
  auto('Auto', null),
  nano('n', 1e9),
  micro('μ', 1e6),
  milli('m', 1e3),
  base('', 1),
  kilo('k', 1e-3),
  mega('M', 1e-6);

  const DisplayUnit(this.prefix, this.multiplier);

  /// The prefixes a bench meter offers for [baseUnit]: resistance ranges
  /// span Ω to MΩ, temperatures are never prefixed, and voltage/current span
  /// nano to kilo.
  static List<DisplayUnit> choicesFor(String baseUnit) => switch (baseUnit) {
    'Ω' => const [auto, base, kilo, mega],
    '°C' || '°F' => const [auto, base],
    _ => const [auto, nano, micro, milli, base, kilo],
  };

  final String prefix;
  final double? multiplier;

  String label(String baseUnit) =>
      this == DisplayUnit.auto ? 'Auto' : '$prefix$baseUnit';

  SiScale scaleFor(double value) => multiplier == null
      ? SiScale.forValue(value)
      : SiScale(multiplier!, prefix);
}

/// Formats readings the way a bench meter does: the prefix and decimal
/// point are fixed by the range, so digits do not jump around while the
/// value changes, and only as many digits are shown as the ADC resolves.
class ReadingFormat {
  const ReadingFormat({
    required this.units,
    required this.fullScale,
    required this.significantDigits,
    this.displayUnit = DisplayUnit.auto,
  });

  final String units;

  /// Full scale of the active range in [units], or null when unknown.
  final double? fullScale;
  final int significantDigits;
  final DisplayUnit displayUnit;

  /// Temperatures read in tenths at best; more digits would be noise.
  static const _temperatureDecimals = 2;

  SiScale scaleFor(double value) {
    if (displayUnit != DisplayUnit.auto) return displayUnit.scaleFor(value);
    if (units == '°C' || units == '°F') return const SiScale(1, '');
    final range = fullScale;
    return range == null || range <= 0
        ? SiScale.forValue(value)
        : SiScale.forRange(range);
  }

  int decimalsFor(SiScale scale) {
    if (units == '°C' || units == '°F') return _temperatureDecimals;
    final range = fullScale;
    if (range == null || range <= 0) return 3;
    final scaledRange = range * scale.multiplier;
    final integerDigits = scaledRange < 1
        ? 1
        : (math.log(scaledRange) / math.ln10).floor() + 1;
    return (significantDigits - integerDigits).clamp(0, 6);
  }

  /// The number only, for example "14.240".
  String number(double value) {
    final scale = scaleFor(value);
    return (value * scale.multiplier).toStringAsFixed(decimalsFor(scale));
  }

  /// The prefixed unit for [value], for example "kΩ".
  String unit(double value) => '${scaleFor(value).prefix}$units';

  /// The complete reading, for example "14.240 V".
  String format(double value) => '${number(value)} ${unit(value)}';
}
