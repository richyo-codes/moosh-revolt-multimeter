import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/screens/settings_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps the dark-mode control in Settings', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Show values for floating probes'), findsOneWidget);
  });

  testWidgets('opens the branded About screen', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    final aboutEntry = find.text('MooshRevolt');
    await tester.scrollUntilVisible(aboutEntry, 200);
    await tester.tap(aboutEntry);
    await tester.pumpAndSettle();

    expect(find.text('About MooshRevolt'), findsOneWidget);
    expect(find.text('A modern Mooshimeter client'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('GNU GPL v3.0 or later'),
      200,
    );
    expect(find.textContaining('GNU GPL v3.0 or later'), findsOneWidget);
  });
}
