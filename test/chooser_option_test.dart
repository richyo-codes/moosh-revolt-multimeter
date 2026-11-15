import 'package:flutter_test/flutter_test.dart';
import 'package:mooshimeter_ble/mooshimeter_protocol.dart';

void main() {
  MooshimeterNode chooser(List<String> names) => MooshimeterNode(
    type: MooshimeterType.chooser,
    name: 'TRIGGER',
    id: 12,
    children: [
      for (final name in names)
        MooshimeterNode(type: MooshimeterType.plain, name: name, children: []),
    ],
  );
  test('distinct nonnumeric names never match through null numeric values', () {
    final node = chooser(['OFF', 'ONESHOT', 'CONTINUOUS']);
    expect(chooserOptionIndex(node, 'CONTINUOUS', path: 'SAMPLING:TRIGGER'), 2);
    expect(
      () => chooserOptionIndex(node, 'UNKNOWN', path: 'SAMPLING:TRIGGER'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('UNKNOWN'),
        ),
      ),
    );
  });
  test('mode and analysis choices use the requested exact name', () {
    final node = chooser(['OFF', 'CURRENT', 'VOLTAGE', 'MEAN', 'RMS']);
    for (final name in ['CURRENT', 'VOLTAGE', 'MEAN', 'RMS']) {
      expect(
        chooserOptionIndex(node, name, path: 'MODE'),
        node.children.indexWhere((c) => c.name == name),
      );
    }
  });
  test('numeric sample rates and ranges allow successful equivalence only', () {
    final node = chooser(['OFF', '125.0', '250', '60', '600']);
    expect(chooserOptionIndex(node, '125', path: 'RATE'), 1);
    expect(chooserOptionIndex(node, '600.0', path: 'RANGE'), 4);
    for (final option in ['126', 'AUTO', 'NaN']) {
      expect(
        () => chooserOptionIndex(node, option, path: 'RATE'),
        throwsStateError,
      );
    }
    expect(
      () => chooserOptionIndex(null, '125', path: 'MISSING'),
      throwsStateError,
    );
  });
  test(
    'valid choices write the correct index; invalid choices never write',
    () async {
      final writes = <(int, List<int>)>[];
      Future<void> write(int id, Iterable<int> payload) async {
        writes.add((id, payload.toList()));
      }

      final node = chooser(['OFF', 'ONESHOT', 'CONTINUOUS']);
      await writeChooserOption(
        node,
        'CONTINUOUS',
        path: 'TRIGGER',
        write: write,
      );
      expect(writes, hasLength(1));
      expect(writes.single.$1, 12);
      expect(writes.single.$2, [2]);
      for (final option in ['UNKNOWN', '250']) {
        await expectLater(
          writeChooserOption(node, option, path: 'TRIGGER', write: write),
          throwsStateError,
        );
      }
      expect(writes, hasLength(1));
    },
  );
}
