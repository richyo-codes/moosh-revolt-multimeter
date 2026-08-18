import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mooshimeter_ble/mooshimeter_protocol.dart';

/// Replay BLE notifications from stdin.
///
/// Each input line is one notification as hex bytes, including its sequence
/// byte, for example: `2a 19 00 00 80 3f`.
Future<void> main() async {
  final reassembler = MooshimeterSerialReassembler();
  final decoder = MooshimeterFrameDecoder();

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    try {
      final bytes = Uint8List.fromList(
        trimmed
            .split(RegExp(r'[\s,:-]+'))
            .map((part) => int.parse(part, radix: 16))
            .toList(),
      );
      for (final serialBytes in reassembler.add(bytes)) {
        for (final frame in decoder.add(serialBytes)) {
          stdout.writeln(
            'node=${frame.nodeId} write=${frame.isWrite} payload=${_hex(frame.payload)}',
          );
          if (frame.nodeId == 1 && frame.payload.length >= 2) {
            final length = frame.payload[0] | (frame.payload[1] << 8);
            if (frame.payload.length >= length + 2) {
              final compressed = Uint8List.fromList(
                frame.payload.sublist(2, length + 2),
              );
              final tree = MooshimeterTreeParser.parse(compressed);
              decoder.installTree(tree);
              stdout.writeln('tree=${tree.path} nodes installed');
            }
          }
        }
      }
    } on FormatException catch (error) {
      stderr.writeln('invalid input: $error');
    }
  }
}

String _hex(Iterable<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
