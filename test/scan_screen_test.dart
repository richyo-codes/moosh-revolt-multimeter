import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/l10n/app_localizations.dart';
import 'package:moosh_revolt/models/remembered_device.dart';
import 'package:moosh_revolt/screens/scan_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:provider/provider.dart';

class _SavedSettings extends SettingsProvider {
  @override
  List<RememberedDevice> get rememberedDevices => List.generate(
    8,
    (i) => RememberedDevice(
      address: 'meter-$i',
      name: 'Workshop meter $i',
      rememberedAt: DateTime(2026),
    ),
  );
}

void main() {
  testWidgets('an unavailable adapter leaves Scan ready to retry', (
    tester,
  ) async {
    var probes = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => BleProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScanScreen(
            bluetoothAvailable: () async {
              probes++;
              return false;
            },
            onDeviceSelected: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bluetooth unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(probes, 1);

    await tester.tap(find.byTooltip('Scan'));
    await tester.pumpAndSettle();
    expect(probes, 2);
    await tester.pump(const Duration(seconds: 12));
    expect(find.textContaining('Bluetooth unavailable'), findsOneWidget);
  });

  testWidgets('Tab and Enter reach the scan menu on a 480×320 display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var openedSettings = false;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => BleProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/settings': (_) {
              openedSettings = true;
              return const Scaffold();
            },
          },
          home: ScanScreen(
            checkConnectedDevices: false,
            onDeviceSelected: (_) async => false,
          ),
        ),
      ),
    );

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < 3; i++) {
      await press(LogicalKeyboardKey.tab);
    }
    await press(LogicalKeyboardKey.enter);
    expect(find.text('Settings'), findsOneWidget);
    await press(LogicalKeyboardKey.tab);
    await press(LogicalKeyboardKey.enter);
    expect(openedSettings, isTrue);
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('saved meters remain reachable at $size in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => _SavedSettings(),
            ),
            ChangeNotifierProvider<BleProvider>(create: (_) => BleProvider()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ScanScreen(
              checkConnectedDevices: false,
              onDeviceSelected: (_) async => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Workshop meter 7'), 200);
      expect(find.text('Workshop meter 7').hitTestable(), findsOneWidget);
      expect(find.text('No devices detected'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
