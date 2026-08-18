import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:provider/provider.dart';
import 'package:moosh_revolt/screens/scan_screen.dart';
import 'package:moosh_revolt/screens/device_screen.dart';
import 'package:moosh_revolt/screens/settings_screen.dart';
import 'package:moosh_revolt/screens/about_screen.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/services/mock_ble_provider.dart';

// --- Shared service instances & navigation key ---
final SettingsProvider settingsProvider = SettingsProvider();
const mockMode = bool.fromEnvironment('MOOSHREVOLT_MOCK');
final MockBleProvider? mockBleProvider = mockMode ? MockBleProvider() : null;
final BleProvider bleProvider = mockBleProvider ?? BleProvider();
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable verbose universal_ble logging for debugging
  await UniversalBle.setLogLevel(BleLogLevel.verbose);

  // Initialize settings (loads remembered devices, autoconnect flag, etc.)
  await settingsProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: bleProvider),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'MooshRevolt',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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

  // --- Home page logging ---
  final String _homeLogPrefix = '[HOME]';
  void _homeLog(String msg) => debugPrint('$_homeLogPrefix $msg');

  @override
  void initState() {
    super.initState();
    _homeLog('initState — calling _tryAutoConnect');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.enableBle) return;
      _homeLog('addPostFrameCallback — starting auto-connect');
      _tryAutoConnect();
    });
  }

  /// Attempt to auto-connect to a remembered or already-connected device on app launch.
  Future<void> _tryAutoConnect() async {
    _homeLog('>>> _tryAutoConnect START');
    if (!mounted) {
      _homeLog('    not mounted, aborting');
      return;
    }

    final settings = context.read<SettingsProvider>();
    _homeLog(
      '    autoConnect=${settings.autoConnect} rememberedCount=${settings.rememberedDeviceCount}',
    );
    if (!settings.autoConnect) {
      _homeLog('    autoConnect disabled, aborting');
      return;
    }

    // Step 1: Check for already-connected Mooshimeter devices
    _homeLog('>>> Step 1: checking already-connected devices');
    try {
      final connectedDevices = await UniversalBle.getSystemDevices(
        withServices: [],
      );
      _homeLog(
        '    connectedDevices returned, count=${connectedDevices.length}',
      );

      for (final device in connectedDevices) {
        final name = (device.name ?? '').toLowerCase();
        _homeLog('      checking: "${device.name}" addr=${device.deviceId}');
        if (name.contains('mooshimeter') || name.contains('mooshim')) {
          _homeLog('    ✓ BLE MOOSHIIMETER DETECTED: ${device.name}');
          // Verify this device is remembered before auto-navigating
          final remembered = settings.getRemembered(device.deviceId);
          _homeLog('      remembered=${remembered != null}');
          if (remembered != null) {
            _homeLog('    ✓ remembered, calling _doConnect');
            await _doConnect(device);
            _homeLog('<<< _tryAutoConnect (via connected)');
            return;
          }
        }
      }
      _homeLog('    no mooshimeter in connectedDevices');
    } catch (e) {
      _homeLog('>>> Step 1 FAILED: $e');
    }

    // Step 2: Fall back to scanning for remembered devices
    _homeLog('>>> Step 2: scanning for remembered devices');
    if (settings.rememberedDeviceCount == 0) {
      _homeLog('    no remembered devices, aborting');
      _homeLog('<<< _tryAutoConnect (no remembered devices)');
      return;
    }

    final remembered = settings.getFirstRemembered();
    if (remembered == null) {
      _homeLog('    getFirstRemembered returned null');
      _homeLog('<<< _tryAutoConnect (null remembered)');
      return;
    }

    _homeLog('    remembered=${remembered.name} addr=${remembered.address}');

    BleDevice? found;
    try {
      _homeLog('    stopping any existing scan');
      await UniversalBle.stopScan().catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 300));

      _homeLog('    starting scan (5s)');
      await UniversalBle.startScan();

      _homeLog('    scanning...');
      await for (final bleDevice in UniversalBle.scanStream) {
        final addr = bleDevice.deviceId.toLowerCase();
        final name = (bleDevice.name ?? '').toLowerCase();
        final target = remembered.address.toLowerCase();

        _homeLog(
          '      checking: "${bleDevice.name}" addr="$addr" match=${addr == target}',
        );

        if (addr == target ||
            name.contains(remembered.name.toLowerCase().split(' ').first) ||
            name.contains('mooshim')) {
          _homeLog('    ✓ MATCH FOUND!');
          found = bleDevice;
          break;
        }
      }
      _homeLog('    scan loop ended, found=${found != null}');
    } catch (e) {
      _homeLog('>>> Step 2 FAILED: $e');
    } finally {
      _homeLog('    cleanup: stopping scan');
      await UniversalBle.stopScan().catchError((_) {});
    }

    if (found != null) {
      _homeLog('    calling _doConnect');
      await _doConnect(found);
    } else {
      _homeLog('>>> _tryAutoConnect FAILED: no device found');
    }
    _homeLog('<<< _tryAutoConnect END');
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
    return ScanScreen(
      onDeviceSelected: _onDeviceSelected,
      connectedDevice: _connectedDevice,
      checkConnectedDevices: widget.enableBle,
    );
  }
}
