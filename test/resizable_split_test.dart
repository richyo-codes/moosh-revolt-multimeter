import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/widgets/resizable_split.dart';

void main() {
  Future<List<double>> pumpSplit(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <double>[];
    var fraction = 0.4;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 1012,
              height: 400,
              child: ResizableSplit(
                axis: Axis.horizontal,
                fraction: fraction,
                onChanged: (value) => setState(() {
                  fraction = value;
                  changes.add(value);
                }),
                first: const ColoredBox(
                  key: ValueKey('first'),
                  color: Colors.red,
                ),
                second: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  double firstWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const ValueKey('first'))).width;

  testWidgets('dragging the divider resizes and reports once', (tester) async {
    final changes = await pumpSplit(tester);
    expect(firstWidth(tester), closeTo(400, 1));

    await tester.drag(
      find.byTooltip('Drag to resize · double-click to reset'),
      const Offset(200 + kDragSlopDefault, 0),
    );
    await tester.pumpAndSettle();

    expect(firstWidth(tester), closeTo(600, 2));
    expect(changes, hasLength(1));
    expect(changes.single, closeTo(0.6, 0.01));
  });

  testWidgets('clamps to the limits and double-click resets', (tester) async {
    final changes = await pumpSplit(tester);
    await tester.drag(
      find.byTooltip('Drag to resize · double-click to reset'),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    expect(changes.last, closeTo(0.15, 0.001));

    final handle = find.byTooltip('Drag to resize · double-click to reset');
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(changes.last, closeTo(0.4, 0.001));
  });
}
