import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';

/// The relevant part of a real Mooshimeter V.1 configuration tree.
MooshimeterNode _tree() {
  MooshimeterNode node(
    String name,
    MooshimeterType type, [
    List<MooshimeterNode Function(MooshimeterNode)> children = const [],
    MooshimeterNode? parent,
  ]) {
    final n = MooshimeterNode(
      type: type,
      name: name,
      children: [],
      parent: parent,
    );
    n.children.addAll(children.map((build) => build(n)));
    return n;
  }

  MooshimeterNode Function(MooshimeterNode) plain(
    String name, [
    List<String> children = const [],
  ]) =>
      (parent) => node(name, MooshimeterType.plain, [
        for (final child in children)
          (p) => node(child, MooshimeterType.plain, const [], p),
      ], parent);

  MooshimeterNode Function(MooshimeterNode) chooser(
    String name,
    List<MooshimeterNode Function(MooshimeterNode)> options,
  ) =>
      (parent) => node(name, MooshimeterType.chooser, options, parent);

  return node('', MooshimeterType.plain, [
    (root) => node('CH1', MooshimeterType.plain, [
      chooser('MAPPING', [
        plain('CURRENT', ['10']),
        plain('TEMP', ['350']),
      ]),
    ], root),
    (root) => node('CH2', MooshimeterType.plain, [
      chooser('MAPPING', [
        plain('VOLTAGE', ['60', '600']),
        plain('TEMP', ['350']),
      ]),
    ], root),
    chooser('SHARED', [
      plain('AUX_V', ['0.1', '0.3', '1.2']),
      plain('RESISTANCE', [
        '1000.0',
        '10000.0',
        '100000.0',
        '1000000.0',
        '10000000.0',
      ]),
      plain('DIODE', ['1.2']),
    ]),
  ]);
}

void main() {
  test('reads ranges for dedicated and shared inputs from the tree', () {
    final tree = _tree();
    expect(MeterRanges.forInput(tree, 1, MeterInput.ch2Default), [60, 600]);
    expect(MeterRanges.forInput(tree, 0, MeterInput.ch1Default), [10]);
    expect(
      MeterRanges.forInput(
        tree,
        1,
        const MeterInput(mapping: 'SHARED', shared: 'RESISTANCE'),
      ),
      [1e3, 1e4, 1e5, 1e6, 1e7],
    );
  });

  test('flags readings beyond 120% of full scale as overload', () {
    expect(MeterRanges.isOverload(1265.95, 1000), isTrue);
    expect(MeterRanges.isOverload(-1.3, 1000), isFalse);
    expect(MeterRanges.isOverload(double.nan, 1000), isTrue);
  });

  test('ranges up one step at a time when saturated', () {
    const ohms = [1e3, 1e4, 1e5, 1e6, 1e7];
    expect(MeterRanges.autorange(ohms, 0, double.infinity), 1);
    expect(MeterRanges.autorange(ohms, 4, double.infinity), 4);
  });

  test('ranges down straight to the smallest range that fits', () {
    const ohms = [1e3, 1e4, 1e5, 1e6, 1e7];
    // Probes shorted on the 10 MΩ range: jump to 1 kΩ at once.
    expect(MeterRanges.autorange(ohms, 4, 0.8), 0);
    expect(MeterRanges.autorange(ohms, 4, 4700), 1);
    // Hysteresis keeps a value near a boundary on its range.
    expect(MeterRanges.autorange(ohms, 1, 950), 1);
  });

  test('derives significant digits from rate and buffer depth', () {
    expect(
      MeterRanges.significantDigits(sampleRateIndex: 0, bufferDepth: 64),
      6,
    );
    expect(
      MeterRanges.significantDigits(sampleRateIndex: 5, bufferDepth: 256),
      5,
    );
    expect(
      MeterRanges.significantDigits(sampleRateIndex: 6, bufferDepth: 64),
      4,
    );
  });

  test('only one channel may use the shared input', () {
    final provider = BleProvider();
    const resistance = MeterInput(mapping: 'SHARED', shared: 'RESISTANCE');
    expect(provider.canUseInput(0, resistance), isTrue);
  });

  test('decodes signed little-endian sample buffers', () {
    // 8-bit: 0x7A = 122, 0xD9 = -39 (as sent by a V.1 at 125 Hz).
    expect(decodeSampleBuffer(Uint8List.fromList([122, 217]), 8, 2), [
      244,
      -78,
    ]);
    // 16-bit: 0x0100 = 256, 0xFFFF = -1.
    expect(decodeSampleBuffer(Uint8List.fromList([0, 1, 255, 255]), 16, 1), [
      256,
      -1,
    ]);
    // 24-bit: 0x7FFFFF and 0x800000.
    expect(
      decodeSampleBuffer(Uint8List.fromList([255, 255, 127, 0, 0, 128]), 24, 1),
      [8388607, -8388608],
    );
  });
}
