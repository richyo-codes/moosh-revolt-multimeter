import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The value encoding used by a config-tree node.
enum MooshimeterType {
  plain,
  link,
  chooser,
  u8,
  u16,
  u32,
  s8,
  s16,
  s32,
  string,
  binary,
  float,
}

MooshimeterType mooshimeterTypeFromCode(int code) {
  if (code < 0 || code > 11) {
    throw FormatException('Unknown Mooshimeter type code: $code');
  }
  return MooshimeterType.values[code];
}

/// A node from the device's runtime configuration tree.
class MooshimeterNode {
  MooshimeterNode({
    required this.type,
    required this.name,
    required this.children,
    this.id,
    this.parent,
  });

  final MooshimeterType type;
  final String name;
  final List<MooshimeterNode> children;
  final MooshimeterNode? parent;
  int? id;

  String get path =>
      parent == null || parent!.name.isEmpty ? name : '${parent!.path}:$name';

  MooshimeterNode? find(String nodePath) {
    if (path == nodePath) return this;
    for (final child in children) {
      final result = child.find(nodePath);
      if (result != null) return result;
    }
    return null;
  }
}

/// Parses the zlib-compressed tree returned by ADMIN:TREE.
class MooshimeterTreeParser {
  static MooshimeterNode parse(Uint8List compressed) {
    final bytes = Uint8List.fromList(
      const ZLibDecoder().decodeBytes(compressed),
    );
    final reader = _Reader(bytes);
    final root = _parseNode(reader, null);
    var nextId = 0;
    void assign(MooshimeterNode node) {
      if (node.type != MooshimeterType.plain &&
          node.type != MooshimeterType.link) {
        node.id = nextId++;
      }
      for (final child in node.children) {
        assign(child);
      }
    }

    assign(root);
    return root;
  }

  static MooshimeterNode _parseNode(_Reader reader, MooshimeterNode? parent) {
    final type = mooshimeterTypeFromCode(reader.u8());
    final name = reader.text(reader.u8());
    final node = MooshimeterNode(
      type: type,
      name: name,
      children: [],
      parent: parent,
    );
    final childCount = reader.u8();
    for (var i = 0; i < childCount; i++) {
      node.children.add(_parseNode(reader, node));
    }
    return node;
  }
}

/// Reassembles the serial stream carried by BLE notifications.
/// Each BLE notification is [sequence number][1..19 serial bytes].
class MooshimeterSerialReassembler {
  final Map<int, Uint8List> _pending = {};
  int? _nextSequence;

  List<Uint8List> add(Uint8List blePacket) {
    if (blePacket.isEmpty) {
      return const [];
    }
    final sequence = blePacket[0];
    _pending[sequence] = Uint8List.fromList(blePacket.sublist(1));
    _nextSequence ??= sequence;
    final output = <Uint8List>[];
    while (_nextSequence != null && _pending.containsKey(_nextSequence)) {
      output.add(_pending.remove(_nextSequence)!);
      _nextSequence = (_nextSequence! + 1) & 0xff;
    }
    return output;
  }

  void reset() {
    _pending.clear();
    _nextSequence = null;
  }
}

class MooshimeterFrame {
  MooshimeterFrame(this.nodeId, this.isWrite, this.payload);
  final int nodeId;
  final bool isWrite;
  final Uint8List payload;
}

/// Decodes config-tree frames after BLE sequence bytes have been removed.
class MooshimeterFrameDecoder {
  final List<int> _buffer = [];
  final Map<int, MooshimeterType> nodeTypes = {
    0: MooshimeterType.u32,
    1: MooshimeterType.binary,
    2: MooshimeterType.string,
  };

  List<MooshimeterFrame> add(Uint8List serialBytes) {
    _buffer.addAll(serialBytes);
    final frames = <MooshimeterFrame>[];
    while (_buffer.isNotEmpty) {
      final nodeByte = _buffer[0];
      final nodeId = nodeByte & 0x7f;
      final type = nodeTypes[nodeId];
      if (type == null) {
        break;
      }
      final payloadLength = _payloadLength(type);
      if (payloadLength == null || _buffer.length < 1 + payloadLength) {
        break;
      }
      final payload = Uint8List.fromList(_buffer.sublist(1, 1 + payloadLength));
      _buffer.removeRange(0, 1 + payloadLength);
      frames.add(MooshimeterFrame(nodeId, (nodeByte & 0x80) != 0, payload));
    }
    return frames;
  }

  void installTree(MooshimeterNode root) {
    nodeTypes
      ..clear()
      ..addAll(_collectTypes(root));
  }

  void reset() {
    _buffer.clear();
    nodeTypes
      ..clear()
      ..addAll({
        0: MooshimeterType.u32,
        1: MooshimeterType.binary,
        2: MooshimeterType.string,
      });
  }

  Map<int, MooshimeterType> _collectTypes(MooshimeterNode root) {
    final result = <int, MooshimeterType>{};
    void visit(MooshimeterNode node) {
      if (node.id != null) {
        result[node.id!] = node.type;
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    return result;
  }

  int? _payloadLength(MooshimeterType type) {
    switch (type) {
      case MooshimeterType.plain:
      case MooshimeterType.link:
        return 0;
      case MooshimeterType.chooser:
      case MooshimeterType.u8:
      case MooshimeterType.s8:
        return 1;
      case MooshimeterType.u16:
      case MooshimeterType.s16:
        return 2;
      case MooshimeterType.u32:
      case MooshimeterType.s32:
      case MooshimeterType.float:
        return 4;
      case MooshimeterType.string:
      case MooshimeterType.binary:
        if (_buffer.length < 3) {
          return null;
        }
        return 2 + _buffer[1] + (_buffer[2] << 8);
    }
  }
}

class _Reader {
  _Reader(this.bytes);
  final Uint8List bytes;
  int offset = 0;

  int u8() {
    if (offset >= bytes.length) {
      throw const FormatException('Truncated tree');
    }
    return bytes[offset++];
  }

  String text(int length) {
    if (offset + length > bytes.length) {
      throw const FormatException('Truncated tree name');
    }
    final value = String.fromCharCodes(bytes.sublist(offset, offset + length));
    offset += length;
    return value;
  }
}

int mooshimeterCrc32(Uint8List data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    var value = (crc ^ byte) & 0xff;
    for (var i = 0; i < 8; i++) {
      value = (value & 1) == 1 ? (value >>> 1) ^ 0xedb88320 : value >>> 1;
    }
    crc = (crc >>> 8) ^ value;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
