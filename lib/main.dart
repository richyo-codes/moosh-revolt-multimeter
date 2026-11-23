import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moosh_revolt/l10n/app_localizations.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:provider/provider.dart';
import 'package:moosh_revolt/screens/scan_screen.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/screens/settings_screen.dart';
import 'package:moosh_revolt/screens/about_screen.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/services/startup_autoconnect.dart';
import 'package:moosh_revolt/services/linux_bluetooth.dart';
import 'package:moosh_revolt/services/mock_ble_provider.dart';
import 'package:moosh_revolt/services/csv_recorder.dart';
import 'package:moosh_revolt/services/prometheus_exporter.dart';

// --- Shared service instances & navigation key ---
final SettingsProvider settingsProvider = SettingsProvider();
const mockMode = bool.fromEnvironment('MOOSHREVOLT_MOCK');
final MockBleProvider? mockBleProvider = mockMode ? MockBleProvider() : null;
final BleProvider bleProvider = mockBleProvider ?? BleProvider();
final PrometheusExporter prometheusExporter = PrometheusExporter(bleProvider);
final CsvRecorder csvRecorder = CsvRecorder(
  bleProvider,
  mathFunction: () => settingsProvider.mathFunction,
);
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable verbose universal_ble logging for debugging
  await UniversalBle.setLogLevel(BleLogLevel.verbose);

  // Initialize settings (loads remembered devices, autoconnect flag, etc.)
  await settingsProvider.init();
  // Restore the saved measurement modes; they are sent to the meter when it
  // connects.
  for (final channel in const [0, 1]) {
    await bleProvider.setInput(
      channel,
      settingsProvider.channelMode(channel).input,
    );
  }

  bleProvider.autoReconnect = settingsProvider.autoReconnect;
  settingsProvider.addListener(
    () => bleProvider.autoReconnect = settingsProvider.autoReconnect,
  );

  // Keep the metrics endpoint in step with its settings.
  void configureExporter() => unawaited(
    prometheusExporter.configure(
      enabled: settingsProvider.exporterEnabled,
      port: settingsProvider.exporterPort,
      allowRemote: settingsProvider.exporterAllowRemote,
    ),
  );
  settingsProvider.addListener(configureExporter);
  configureExporter();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: bleProvider),
        ChangeNotifierProvider.value(value: prometheusExporter),
        ChangeNotifierProvider.value(value: csvRecorder),
      ],
      child: const MooshimeterApp(mockMode: mockMode),
    ),
  );
}

class MooshimeterApp extends StatelessWidget {
  const MooshimeterApp({
    super.key,
    this.enableBle = true,
    this.mockMode = false,
  });

  final bool enableBle;
  final bool mockMode;

  static ThemeData _appTheme(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );
    final focusColor = colors.primary.withValues(alpha: 0.30);
    final keyboardFocus = ButtonStyle(
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? focusColor : null,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: colors.primary, width: 3)
            : null,
      ),
    );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      focusColor: focusColor,
      iconButtonTheme: IconButtonThemeData(style: keyboardFocus),
      filledButtonTheme: FilledButtonThemeData(style: keyboardFocus),
      outlinedButtonTheme: OutlinedButtonThemeData(style: keyboardFocus),
      textButtonTheme: TextButtonThemeData(style: keyboardFocus),
      elevatedButtonTheme: ElevatedButtonThemeData(style: keyboardFocus),
      switchTheme: SwitchThemeData(overlayColor: keyboardFocus.overlayColor),
      appBarTheme: brightness == Brightness.light
          ? const AppBarTheme(elevation: 0, centerTitle: false)
          : null,
      cardTheme: brightness == Brightness.light
          ? CardThemeData(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : null,
      inputDecorationTheme: brightness == Brightness.light
          ? InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: settings.locale,
      title: 'MooshRevolt',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: _appTheme(Brightness.light),
      darkTheme: _appTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: HomePage(enableBle: enableBle, mockMode: mockMode),
      routes: {
        '/settings': (_) => const SettingsScreen(),
        '/about': (_) => const AboutScreen(),
      },
    );
  }
}

/// Home page that manages navigation state and auto-connect.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.enableBle = true, this.mockMode = false});

  final bool enableBle;
  final bool mockMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BleDevice? _connectedDevice;
  bool _startupDiscovery = false;

  // --- Home page logging ---
  final String _homeLogPrefix = '[HOME]';
  void _homeLog(String msg) => debugPrint('$_homeLogPrefix $msg');

  @override
  void initState() {
    super.initState();
    _startupDiscovery = widget.enableBle && !widget.mockMode;
    _homeLog('initState — calling _tryAutoConnect');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_startupDiscovery) return;
      _homeLog('addPostFrameCallback — starting auto-connect');
      _tryAutoConnect().whenComplete(() {
        if (mounted) setState(() => _startupDiscovery = false);
      });
    });
  }

  /// Attempt to connect only to an enabled, remembered address on launch.
  Future<void> _tryAutoConnect() async {
    if (!mounted) return;
    try {
      final settings = context.read<SettingsProvider>();
      if (!settings.autoConnect ||
          !settings.rememberedDevices.any((device) => device.autoConnect) ||
          !await canDiscoverBluetooth() ||
          !mounted) {
        return;
      }
      final device = await findStartupDevice(
        settings: settings,
        systemDevices: () => UniversalBle.getSystemDevices(withServices: []),
        scanStream: UniversalBle.scanStream,
        startScan: () => UniversalBle.startScan(),
        stopScan: UniversalBle.stopScan,
      );
      if (device != null && mounted) await _doConnect(device);
    } catch (error) {
      _homeLog('Startup discovery failed: $error');
    }
  }

  Future<bool> _doConnect(BleDevice device) async {
    _homeLog('>>> _doConnect "${device.name}" addr=${device.deviceId}');
    final wasMounted = mounted;
    if (!wasMounted) {
      _homeLog('    not mounted, aborting');
      return false;
    }

    // Guard: if already connected/connecting to this device, skip.
    _homeLog('    provider state=${bleProvider.state}');
    if (bleProvider.state != MmConnectionState.disconnected) {
      _homeLog('    skipping (state: ${bleProvider.state})');
      return false;
    }

    _homeLog('    calling bleProvider.connect()');
    final success = await bleProvider.connect(
      device,
      sampleRate: context.read<SettingsProvider>().sampleRate,
    );
    _homeLog(
      '    connect returned success=$success, state=${bleProvider.state}',
    );

    if (!mounted) {
      _homeLog('    not mounted after connect');
      return false;
    }

    if (success) {
      _homeLog('    SUCCESS — navigating to DeviceScreen');
      setState(() => _connectedDevice = device);

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DeviceScreen(device: device)),
        (route) => false, // remove all existing routes
      );
      _homeLog('<<< _doConnect SUCCESS');
      return true;
    } else {
      _homeLog('>>> _doConnect FAILED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to device'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<bool> _onDeviceSelected(BleDevice device) async {
    _homeLog('>>> _onDeviceSelected "${device.name}" addr=${device.deviceId}');
    return _doConnect(device);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mockMode) {
      return DeviceScreen(device: mockBleProvider!.device);
    }
    // Discovery owns the BLE scan until its deadline. Do not mount ScanScreen
    // yet: its automatic/manual scan would compete with startup discovery.
    if (_startupDiscovery) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ScanScreen(
      onDeviceSelected: _onDeviceSelected,
      connectedDevice: _connectedDevice,
      checkConnectedDevices: widget.enableBle,
    );
  }
}
