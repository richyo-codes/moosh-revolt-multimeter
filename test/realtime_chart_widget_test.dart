import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/widgets/realtime_chart.dart';

void main() {
  final points = [for (var i = 0; i < 10; i++) LinePoint(i.toDouble(), 1)];

  Future<void> pumpChart(
    WidgetTester tester, {
    bool showCh1 = true,
    bool showCh2 = true,
    ValueChanged<bool>? onCh2VisibilityChanged,
    bool ch1Continuity = false,
    List<LinePoint>? ch1Points,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: RealtimeChart(
              ch1Points: ch1Points ?? points,
              ch2Points: points,
              showCh1: showCh1,
              showCh2: showCh2,
              onCh2VisibilityChanged: onCh2VisibilityChanged,
              ch1Continuity: ch1Continuity,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a hidden channel is not plotted but stays in the legend', (
    tester,
  ) async {
    bool? requested;
    await pumpChart(
      tester,
      showCh2: false,
      onCh2VisibilityChanged: (visible) => requested = visible,
    );
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byKey(const ValueKey('legend-ch2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('legend-ch2')));
    expect(requested, isTrue);
  });

  testWidgets('both channels hidden explains how to show one', (tester) async {
    await pumpChart(tester, showCh1: false, showCh2: false);
    expect(find.byType(LineChart), findsNothing);
    expect(find.textContaining('Both channels are hidden'), findsOneWidget);
  });

  testWidgets('continuity mode plots open/continuous as a step trace', (
    tester,
  ) async {
    await pumpChart(
      tester,
      showCh2: false,
      ch1Continuity: true,
      ch1Points: [LinePoint(0, 1265.9), LinePoint(1, -1.2), LinePoint(2, 900)],
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bar = chart.data.lineBarsData.single;
    expect(bar.isStepLineChart, isTrue);
    expect(bar.spots.map((s) => s.y), [0, 1, 0]);
  });
}
