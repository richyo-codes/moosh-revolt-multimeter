import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moosh_revolt/l10n/app_localizations.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';

import 'responsive_device_screen_test.dart' show FakeBleProvider;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(480, 320),
    const Size(800, 480),
    const Size(1280, 800),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('merged meter and configuration fit $size, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = SettingsProvider();
        final provider = FakeBleProvider(ch1: -0.003, ch2: 1.2);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<BleProvider>.value(value: provider),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.25)),
                child: child!,
              ),
              locale: Locale(dark ? 'fr' : 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: DeviceScreen(
                device: BleDevice(
                  deviceId: 'AA:BB:CC:DD:EE:FF',
                  name: 'Test meter',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(dark ? '1,2000' : '1.2000'), findsOneWidget);
        // Both channels must remain operable, including in short landscape.
        final configure = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              (widget.tooltip?.startsWith('Configure CH2') ?? false),
        );
        expect(configure, findsOneWidget);
        await tester.ensureVisible(configure);
        await tester.tap(configure);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width < 900) {
          expect(find.text('CH2 configuration'), findsOneWidget);
          await tester.tap(find.byType(CloseButton));
          await tester.pumpAndSettle();
        } else {
          expect(
            find.byKey(const ValueKey('channel-config-panel')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
        provider.dispose();
      });
    }
  }
}
