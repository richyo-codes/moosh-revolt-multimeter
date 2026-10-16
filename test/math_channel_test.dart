import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/math_channel.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

class _Provider extends BleProvider {
  @override
  List<double> ranges(int channel) {
    final input = this.input(channel);
    return switch (input.shared ?? input.mapping) {
      'CURRENT' => const [10.0],
      'VOLTAGE' => const [60.0, 600.0],
      'TEMP' => const [350.0],
      _ => const [0.1, 0.3, 1.2],
    };
  }
}

void main() {
  test('converts type-K thermocouple voltages per ITS-90', () {
    // Reference points from the NIST type-K table.
    expect(typeKDeltaCelsius(0), 0);
    expect(typeKDeltaCelsius(4.096e-3), closeTo(100, 0.1));
    expect(typeKDeltaCelsius(8.138e-3), closeTo(200, 0.1));
    expect(typeKDeltaCelsius(20.644e-3), closeTo(500, 0.2));
  });

  test('computes power from current and voltage', () {
    final provider = _Provider();
    final readings = DeviceReadings(
      ch1Value: 2,
      ch2Value: 230,
      timestamp: 0,
      realPower: 414,
    );
    expect(MathFunction.realPower.compute(provider, readings), 414);
    expect(MathFunction.apparentPower.compute(provider, readings), 460);
    expect(MathFunction.powerFactor.compute(provider, readings), 0.9);
  });

  test('needs current and voltage, and reports OL inputs as NaN', () {
    expect(
      MathFunction.realPower.isValid(ChannelMode.current, ChannelMode.voltage),
      isTrue,
    );
    expect(
      MathFunction.realPower.isValid(
        ChannelMode.resistance,
        ChannelMode.voltage,
      ),
      isFalse,
    );
    final provider = _Provider();
    final overloaded = DeviceReadings(
      ch1Value: 2,
      ch2Value: 999,
      timestamp: 0,
      ch2Overload: true,
    );
    expect(
      MathFunction.apparentPower.compute(provider, overloaded).isNaN,
      isTrue,
    );
  });

  test('adds the thermocouple to the meter temperature', () async {
    final provider = _Provider();
    await provider.setInput(0, ChannelMode.auxiliaryVoltageDc.input);
    await provider.setInput(1, ChannelMode.internalTemperature.input);
    final readings = DeviceReadings(
      ch1Value: 4.096e-3,
      ch2Value: 298.15,
      timestamp: 0,
    );
    expect(
      MathFunction.thermocoupleK.compute(provider, readings),
      closeTo(125, 0.1),
    );
  });

  test('suggests the channel setup each function needs', () {
    expect(
      MathFunction.thermocoupleK.setupFor(
        ChannelMode.current,
        ChannelMode.voltage,
      ),
      (ChannelMode.auxiliaryVoltageDc, ChannelMode.internalTemperature),
    );
    expect(
      MathFunction.realPower.setupFor(
        ChannelMode.resistance,
        ChannelMode.voltageAc,
      ),
      (ChannelMode.currentAc, ChannelMode.voltageAc),
    );
  });
}
