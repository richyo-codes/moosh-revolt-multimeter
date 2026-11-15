import 'mooshimeter_protocol.dart';

/// Resolves exact names or successfully parsed numeric equivalents.
int chooserOptionIndex(
  MooshimeterNode? node,
  String option, {
  required String path,
}) {
  final numericOption = double.tryParse(option);
  final index = node?.children.indexWhere(
    (child) =>
        child.name == option ||
        (numericOption != null &&
            numericOption.isFinite &&
            double.tryParse(child.name) == numericOption),
  );
  if (index == null || index < 0) {
    throw StateError('The meter has no option "$option" for $path.');
  }
  return index;
}

/// Resolve before writing so an invalid request cannot change the meter.
Future<void> writeChooserOption(
  MooshimeterNode? node,
  String option, {
  required String path,
  required Future<void> Function(int id, Iterable<int> payload) write,
}) async {
  final index = chooserOptionIndex(node, option, path: path);
  final id = node?.id;
  if (id == null) throw StateError('The meter has no writable node for $path.');
  await write(id, [index]);
}
