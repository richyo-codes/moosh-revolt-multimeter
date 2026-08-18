/// Represents a single voltage/current reading from a Mooshimeter channel.
class MeterReading {
  final double timestamp;
  final double value;
  final String units;
  final int digits;
  final double max;

  MeterReading({
    required this.timestamp,
    required this.value,
    required this.units,
    required this.digits,
    required this.max,
  });

  /// Format the reading for display with appropriate SI prefix.
  String get formatted {
    if (max == 0) return units;
    final scale = SiScale.forValue(value);
    final adjusted = value * scale.multiplier;
    final sign = value >= 0 ? ' ' : '';
    return '$sign${adjusted.toStringAsFixed(digits - 1)}${scale.prefix}$units';
  }

  bool get isOutOfRange => value.abs() > 1.2 * max;
}

/// Channel type for Mooshimeter readings.
enum Channel {
  ch1('Ch1', 'A', 4, 10), // Current input
  ch2('Ch2', 'V', 4, 600); // Voltage input

  const Channel(this.label, this.units, this.digits, this.max);
  final String label;
  final String units;
  final int digits;
  final double max;
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
}

enum DisplayUnit {
  auto('Auto', null),
  nano('n', 1e9),
  micro('μ', 1e6),
  milli('m', 1e3),
  base('', 1),
  kilo('k', 1e-3);

  const DisplayUnit(this.prefix, this.multiplier);

  final String prefix;
  final double? multiplier;

  String label(String baseUnit) =>
      this == DisplayUnit.auto ? 'Auto' : '$prefix$baseUnit';

  SiScale scaleFor(double value) => multiplier == null
      ? SiScale.forValue(value)
      : SiScale(multiplier!, prefix);
}

/// Channel mode (input type) for Mooshimeter.
/// The hardwareIndex maps to the Mooshimeter BLE protocol values:
/// 0=Voltage, 1=Current, 2=Resistance, 3=Diode, 4=Frequency, 5=Period, 6=TempC, 7=TempF
enum ChannelMode {
  auto('Auto', -1),
  voltage('Voltage', 0),
  current('Current', 1),
  resistance('Resistance', 2),
  diode('Diode', 3),
  frequency('Frequency', 4),
  period('Period', 5),
  temperatureC('°C', 6),
  temperatureF('°F', 7);

  const ChannelMode(this.label, this.hardwareIndex);
  final String label;
  final int hardwareIndex;
}

/// A device that has been discovered and possibly connected.
class MooshimeterDevice {
  final String id;
  final String name;
  final String address;
  final int rssi;
  final DateTime discoveredAt;
  final bool isConnected;

  MooshimeterDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
    required this.discoveredAt,
    this.isConnected = false,
  });

  String get rssiLabel {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MooshimeterDevice && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
