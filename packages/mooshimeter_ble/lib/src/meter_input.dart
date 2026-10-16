import 'dart:math' as math;

import 'mooshimeter_protocol.dart';

/// What a channel measures, expressed with the option names of the meter's
/// configuration tree.
///
/// The meter advertises its choosers at runtime (for example `CH1:MAPPING`
/// offers `CURRENT, TEMP, SHARED` and `SHARED` offers
/// `AUX_V, RESISTANCE, DIODE`). Selecting options by name rather than by a
/// hard-coded index keeps every mode pointed at the hardware it names.
class MeterInput {
  const MeterInput({
    required this.mapping,
    this.shared,
    this.analysis = 'MEAN',
  });

  /// The `CHx:MAPPING` option: `CURRENT`, `VOLTAGE`, `TEMP` or `SHARED`.
  final String mapping;

  /// The `SHARED` option when [mapping] is `SHARED`: `AUX_V`, `RESISTANCE`
  /// or `DIODE`.
  final String? shared;

  /// The `CHx:ANALYSIS` option: `MEAN` for DC, `RMS` for AC.
  final String analysis;

  /// Only one channel at a time can use the shared auxiliary input.
  bool get usesShared => shared != null;

  bool get isRms => analysis == 'RMS';

  static const ch1Default = MeterInput(mapping: 'CURRENT');
  static const ch2Default = MeterInput(mapping: 'VOLTAGE');

  @override
  bool operator ==(Object other) =>
      other is MeterInput &&
      other.mapping == mapping &&
      other.shared == shared &&
      other.analysis == analysis;

  @override
  int get hashCode => Object.hash(mapping, shared, analysis);

  @override
  String toString() => 'MeterInput(${shared ?? mapping}${isRms ? ' RMS' : ''})';
}

/// Range, overload and resolution rules shared by the transport and tests.
abstract final class MeterRanges {
  /// The full-scale values the meter offers for [input] on [channel]
  /// (0 = CH1), read from the option node's children, for example
  /// `SHARED:RESISTANCE` → 1 kΩ … 10 MΩ.
  static List<double> forInput(
    MooshimeterNode tree,
    int channel,
    MeterInput input,
  ) {
    final path = input.usesShared
        ? 'SHARED:${input.shared}'
        : 'CH${channel + 1}:MAPPING:${input.mapping}';
    final node = tree.find(path);
    if (node == null) return const [];
    return [for (final child in node.children) ?double.tryParse(child.name)];
  }

  /// A reading beyond 120% of full scale is saturated, not a measurement.
  static const overloadRatio = 1.2;

  /// Step up once the reading passes 110% of the current full scale.
  static const upRatio = 1.1;

  /// Step down to a range only when the reading uses under 90% of it.
  static const downRatio = 0.9;

  static bool isOverload(double raw, double fullScale) =>
      !raw.isFinite || raw.abs() > overloadRatio * fullScale;

  /// The range index auto-ranging should move to, or [current] to stay.
  ///
  /// A saturated reading carries no magnitude, so ranging up moves one step
  /// at a time. A reading on a range that is too large is accurate, so
  /// ranging down jumps straight to the smallest range that fits; this
  /// matters for continuity checks, where stepping down from 10 MΩ one range
  /// per sample would delay a short by seconds.
  static int autorange(List<double> ranges, int current, double raw) {
    if (ranges.isEmpty) return current;
    final magnitude = raw.isFinite ? raw.abs() : double.infinity;
    if (magnitude > upRatio * ranges[current]) {
      return math.min(current + 1, ranges.length - 1);
    }
    for (var i = 0; i < current; i++) {
      if (magnitude < downRatio * ranges[i]) return i;
    }
    return current;
  }

  /// Effective number of bits per sample rate index (125 Hz … 8 kHz), from
  /// the ADS1292 datasheet as used by the original Mooshimeter app.
  static const _baseEnob = [20.10, 19.58, 19.11, 18.49, 17.36, 14.91, 12.53];

  /// Significant digits the reading can honestly show. Averaging a buffer
  /// adds one bit per factor of four samples.
  static int significantDigits({
    required int sampleRateIndex,
    required int bufferDepth,
  }) {
    final index = sampleRateIndex.clamp(0, _baseEnob.length - 1);
    final enob =
        _baseEnob[index] + math.log(math.max(bufferDepth, 1)) / math.log(4);
    return (enob * math.log(2) / math.ln10).floor();
  }
}
