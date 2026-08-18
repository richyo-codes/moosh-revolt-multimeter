// This is a basic Flutter widget test file.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moosh_revolt/main.dart';

void main() {
  testWidgets('MooshRevolt app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: bleProvider),
        ],
        child: const MooshimeterApp(enableBle: false),
      ),
    );

    // Verify that the app title is shown
    expect(find.text('MooshRevolt'), findsOneWidget);
  });
}
