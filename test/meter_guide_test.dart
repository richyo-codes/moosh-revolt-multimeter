import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/math_channel.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/screens/meter_guide_screen.dart';

void main() {
  Future<void> pumpGuide(
    WidgetTester tester, {
    Future<void> Function(GuideSetup)? onSetUp,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MeterGuideScreen(onSetUp: onSetUp),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('explains each jack with typical ranges when offline', (
    tester,
  ) async {
    await pumpGuide(tester);

    expect(find.byKey(const ValueKey('guide-jacks')), findsOneWidget);
    expect(find.text('Voltage · always CH2'), findsOneWidget);
    expect(find.text('Current · always CH1'), findsOneWidget);
    expect(find.textContaining('Ranges 60 V, 600 V'), findsOneWidget);
    expect(find.textContaining('1 kΩ, 10 kΩ, 100 kΩ, 1 MΩ, 10 MΩ'), findsOne);
    expect(find.text('Battery or DC voltage'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);
    // Without a meter screen behind it, recipes cannot set anything up.
    expect(find.text('Set up the meter'), findsNothing);
  });

  testWidgets('sets up a recipe and returns to the meter', (tester) async {
    GuideSetup? applied;
    await pumpGuide(tester, onSetUp: (setup) async => applied = setup);

    await tester.tap(find.byKey(const ValueKey('guide-set-up-Power')));
    await tester.pumpAndSettle();

    expect(applied?.ch1, ChannelMode.current);
    expect(applied?.ch2, ChannelMode.voltage);
    expect(applied?.math, MathFunction.realPower);
    expect(find.text('open'), findsOneWidget);
  });
}
