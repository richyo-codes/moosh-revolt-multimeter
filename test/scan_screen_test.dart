import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
