import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mooshimeter_ble/mooshimeter_protocol.dart';

void main() {
  test('computes the protocol CRC32', () {
    expect(
      mooshimeterCrc32(Uint8List.fromList('123456789'.codeUnits)),
      0xcbf43926,
    );
  });

  test('reassembles out-of-order BLE sequence packets', () {
    final reassembler = MooshimeterSerialReassembler();
    expect(reassembler.add(Uint8List.fromList([1, 0x42])), [
      Uint8List.fromList([0x42]),
    ]);
    expect(reassembler.add(Uint8List.fromList([3, 0x44])), isEmpty);
    expect(reassembler.add(Uint8List.fromList([2, 0x43])), [
      Uint8List.fromList([0x43]),
      Uint8List.fromList([0x44]),
    ]);
  });

  test('decodes fragmented config frames', () {
    final decoder = MooshimeterFrameDecoder();
    decoder.nodeTypes[25] = MooshimeterType.float;
    final first = decoder.add(Uint8List.fromList([25, 0x00, 0x00]));
    expect(first, isEmpty);
    final frames = decoder.add(Uint8List.fromList([0x80, 0x3f]));
    expect(frames.single.nodeId, 25);
    expect(frames.single.payload, [0x00, 0x00, 0x80, 0x3f]);
  });

  test('deserializes and assigns runtime tree IDs depth-first', () {
    // Root plain -> CH1 plain -> VALUE float, compressed with zlib in the fixture.
    final tree = MooshimeterTreeParser.parse(_zlibFixture());
    final value = tree.find('ROOT:CH1:VALUE');
    expect(value?.type, MooshimeterType.float);
    expect(value?.id, 0);
  });
}

Uint8List _zlibFixture() {
  // zlib stream for: ROOT(plain) -> CH1(plain) -> VALUE(float), no children.
  return Uint8List.fromList([
    120,
    156,
    99,
    96,
    9,
    242,
    247,
    15,
    97,
    100,
    96,
    118,
    246,
    48,
    100,
    228,
    102,
    13,
    115,
    244,
    9,
    117,
    101,
    0,
    0,
    37,
    106,
    3,
    151,
  ]);
}
