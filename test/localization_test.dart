import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/l10n/app_localizations.dart';
import 'package:moosh_revolt/l10n/app_localizations_fr.dart';
import 'package:moosh_revolt/main.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';
import 'responsive_device_screen_test.dart' show FakeBleProvider;

void main() {
  test('language preference persists and resets to system', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.init();
    settings.languageCode = 'fr';
    final restored = SettingsProvider();
    await restored.init();
    expect(restored.locale, const Locale('fr'));
    restored.languageCode = null;
    await settings.init();
    expect(settings.locale, isNull);
    settings.dispose();
    restored.dispose();
    expect(AppLocalizationsFr().sampleCount(1), '1 mesure');
    expect(AppLocalizationsFr().sampleCount(3), '3 mesures');
  });

  testWidgets('app changes language live and falls back to English', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<BleProvider>(create: (_) => BleProvider()),
        ],
        child: const MooshimeterApp(enableBle: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect your meter'), findsOneWidget);
    settings.languageCode = 'fr';
    await tester.pumpAndSettle();
    expect(find.text('Connectez votre multimètre'), findsOneWidget);
    settings.languageCode = null;
    await tester.pumpAndSettle();
    expect(find.text('Connect your meter'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('French measurements and controls render at $size', (
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
              create: (_) => SettingsProvider(),
            ),
            ChangeNotifierProvider<BleProvider>(
              create: (_) => FakeBleProvider(ch1: 0.003, ch2: 1.2),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('fr'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DeviceScreen(
              device: BleDevice(deviceId: 'AA:BB:CC:DD:EE:FF', name: 'Test'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tension CC'), findsOneWidget);
      expect(find.text('1,2000'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Déconnecter'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
