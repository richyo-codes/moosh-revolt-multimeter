import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/widgets/readings_display.dart';

Widget _display({
  bool showFloatingValues = false,
  bool showCh1 = true,
  bool showCh2 = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ReadingsDisplay(
        ch1Value: 0,
        ch2Value: 1.2,
        ch1Mode: ChannelMode.current,
        ch2Mode: ChannelMode.voltage,
        ch1PossiblyFloating: true,
        showFloatingValues: showFloatingValues,
        showCh1: showCh1,
        showCh2: showCh2,
      ),
    ),
  );
}

void main() {
  testWidgets('hides a likely floating value by default', (tester) async {
    await tester.pumpWidget(_display());

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Near zero · possibly floating'), findsOneWidget);
    expect(find.text('0.00000'), findsNothing);
  });

  testWidgets('floating value can be shown with the override', (tester) async {
    await tester.pumpWidget(_display(showFloatingValues: true));

    expect(find.text('0.00000'), findsOneWidget);
    expect(find.text('Near zero · possibly floating'), findsOneWidget);
  });

  testWidgets('expires a reading that is no longer fresh', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingsDisplay(
            ch1Value: 2.5,
            ch2Value: 12.8,
            ch1Mode: ChannelMode.current,
            ch2Mode: ChannelMode.voltage,
            hasFreshSample: false,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('Waiting for a fresh sample'), findsNWidgets(2));
    expect(find.text('2.50000'), findsNothing);
  });

  testWidgets('hides an unused channel card completely', (tester) async {
    await tester.pumpWidget(_display(showCh1: false));

    expect(find.text('CH1 · Current DC'), findsNothing);
    expect(find.text('CH2 · Voltage DC'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel-readings-none')), findsNothing);
  });

  testWidgets('keeps a normal reading and its unit together', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 300,
            child: ReadingsDisplay(
              ch1Value: 0.003,
              ch2Value: 1.2,
              ch1Mode: ChannelMode.current,
              ch2Mode: ChannelMode.voltage,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('reading-value-with-unit-CH1 · Current DC')),
      findsOneWidget,
    );
    expect(find.text('mA'), findsOneWidget);
  });

  testWidgets('labels automatic display-unit scaling explicitly', (
    tester,
  ) async {
    await tester.pumpWidget(_display());

    expect(find.text('Units: Auto'), findsNWidgets(2));
    expect(
      find.byTooltip('Display units: Auto chooses an SI prefix'),
      findsNWidgets(2),
    );
  });
}
