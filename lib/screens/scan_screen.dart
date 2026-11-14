import 'package:moosh_revolt/screens/meter_guide_screen.dart';
import 'package:moosh_revolt/l10n/localization.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moosh_revolt/widgets/mooshrevolt_mark.dart';
import 'package:provider/provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:moosh_revolt/widgets/device_tile.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/models/remembered_device.dart';

// --- Screen-level logging ---
String _screenLogPrefix = '[SCAN]';
void _screenLog(String msg) => debugPrint('$_screenLogPrefix $msg');

/// The main scan screen that lists discovered Mooshimeter devices.
class ScanScreen extends StatefulWidget {
  final Future<bool> Function(BleDevice) onDeviceSelected;
  final BleDevice? connectedDevice;
  final bool checkConnectedDevices;

  const ScanScreen({
    super.key,
    required this.onDeviceSelected,
    this.connectedDevice,
    this.checkConnectedDevices = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<_ScanData> _devices = [];
  bool _isScanning = false;
  String Function(BuildContext) _scanStatus = (context) => context.l10n.tapScan;
  int _deviceCount = 0;

  StreamSubscription? _scanSub;
  Timer? _scanTimeout;
  List<BleDevice> _connectedDevices = [];
  List<String> _scanningAddresses = [];
  String? _connectingAddress;

  String _normalizedAddress(String address) =>
      address.toLowerCase().replaceAll('_', '');

  bool _isConnecting(String address) =>
      _connectingAddress == _normalizedAddress(address);

  @override
  void initState() {
    super.initState();
    if (widget.checkConnectedDevices) {
      _checkConnectedDevices();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startScan();
      });
    }
  }

  Future<void> _checkConnectedDevices() async {
    _screenLog('>>> _checkConnectedDevices START');
    try {
      _screenLog('    querying UniversalBle.getSystemDevices()');
      final devices = await UniversalBle.getSystemDevices(withServices: []);
      _screenLog('    getSystemDevices returned, length=${devices.length}');
      final mooshimDevices = devices.where((d) {
        final name = (d.name ?? '').toLowerCase();
        final isMatch =
            name.contains('mooshimeter') || name.contains('mooshim');
        _screenLog('      addr=${d.deviceId} name="$name" match=$isMatch');
        return isMatch;
      }).toList();
      _screenLog('    mooshimDevices found: ${mooshimDevices.length}');
      if (mounted) {
        setState(() => _connectedDevices = mooshimDevices);
        _screenLog('    setState -> _connectedDevices updated');
      }
    } catch (e) {
      _screenLog('>>> _checkConnectedDevices FAILED: $e');
    }
    _screenLog('<<< _checkConnectedDevices END');
  }

  void _startScan() async {
    _screenLog('>>> _startScan START');
    if (!mounted) return;
    _scanTimeout?.cancel();
    setState(() {
      _isScanning = true;
      _scanStatus = (context) => context.l10n.scanning;
      _devices.clear();
      _scanningAddresses = [];
      _deviceCount = 0;
    });

    try {
      _screenLog('    cancelling existing _scanSub');
      await _scanSub?.cancel();
      if (!mounted) return;
      _scanSub = null;

      _scanSub = UniversalBle.scanStream.listen((bleDevice) {
        if (!mounted) return;
        _screenLog(
          '>>> scanStream callback: name="${bleDevice.name}" rssi=${bleDevice.rssi} addr=${bleDevice.deviceId}',
        );
        setState(() {
          final name = (bleDevice.name ?? '').toLowerCase();
          if (name.contains('mooshimeter') || name.contains('mooshim')) {
            final address = bleDevice.deviceId.toLowerCase();
            final existingIndex = _scanningAddresses.indexOf(address);
            if (existingIndex >= 0) {
              _devices[existingIndex] = _ScanData(
                device: bleDevice,
                rssi: bleDevice.rssi ?? -999,
              );
            } else {
              _screenLog('    ✓ MATCH — added to list');
              _devices.add(
                _ScanData(device: bleDevice, rssi: bleDevice.rssi ?? -999),
              );
              _scanningAddresses.add(address);
            }
          }
          _deviceCount = _devices.length;
          if (_deviceCount > 0) {
            _scanStatus = (context) => context.l10n.foundDevices(_deviceCount);
            _screenLog('    _deviceCount=$_deviceCount');
          } else {
            _scanStatus = (context) => context.l10n.scanning;
          }
        });
      });

      _screenLog('    calling UniversalBle.startScan()');
      await UniversalBle.startScan();
      _screenLog('<<< startScan returned OK');
    } catch (e) {
      _screenLog('>>> _startScan FAILED: $e');
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanStatus = (context) => context.l10n.errorMessage(e.toString());
      });
      await _scanSub?.cancel();
      _scanSub = null;
    }

    if (!mounted) return;
    _screenLog('    scheduling 11s scan timeout...');
    _scanTimeout = Timer(Duration(seconds: 11), () {
      if (!mounted) return;
      _screenLog('>>> timeout reached, calling _stopScan');
      unawaited(_stopScan());
    });
  }

  Future<void> _stopScan() async {
    _screenLog('>>> _stopScan');
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      _screenLog('    calling UniversalBle.stopScan()');
      await UniversalBle.stopScan();
      _screenLog('<<< stopScan returned');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      if (_deviceCount == 0) {
        _scanStatus = (context) => context.l10n.noneFound;
      }
    });
    _screenLog('<<< _stopScan complete, found=$_deviceCount');
  }

  Future<void> _selectDevice(BleDevice device) async {
    _screenLog(
      '>>> _selectDevice "${device.name}" addr=${device.deviceId} isScanning=$_isScanning',
    );
    if (_isScanning) {
      _screenLog('    stopping scan first');
      await _stopScan();
    }
    if (!mounted) return;
    setState(() {
      _connectingAddress = _normalizedAddress(device.deviceId);
      _scanStatus = (context) =>
          context.l10n.connectingTo(device.name ?? 'Mooshimeter');
    });
    _screenLog('    calling widget.onDeviceSelected');
    final connected = await widget.onDeviceSelected(device);
    if (!mounted) return;
    setState(() {
      _connectingAddress = null;
      if (!connected) _scanStatus = (context) => context.l10n.connectFailed;
    });
    _screenLog('<<< _selectDevice connected=$connected');
  }

  @override
  void dispose() {
    _scanTimeout?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MooshRevoltMark(),
              SizedBox(width: 10),
              Text('MooshRevolt'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Meter guide',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MeterGuideScreen()),
            ),
          ),
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _connectingAddress != null
                ? null
                : (_isScanning ? _stopScan : _startScan),
            tooltip: _isScanning ? context.l10n.stopScan : context.l10n.scan,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'settings',
                child: Text(context.l10n.settings),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final colors = Theme.of(context).colorScheme;
          final provider = context.watch<BleProvider>();
          final remembered = settings.rememberedDevices;
          final busy = _connectingAddress != null;
          return SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Text(
                      context.l10n.connectYourMeter,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      context.l10n.wakeMeter,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    SizedBox(height: 20),
                    Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bluetooth_searching,
                                  color: colors.primary,
                                ),
                                SizedBox(width: 12),
                                Expanded(child: Text(_scanStatus(context))),
                              ],
                            ),
                            if (_isScanning || busy) ...[
                              SizedBox(height: 12),
                              LinearProgressIndicator(),
                            ],
                            SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: busy
                                  ? null
                                  : (_isScanning ? _stopScan : _startScan),
                              icon: Icon(
                                _isScanning ? Icons.stop : Icons.search,
                              ),
                              label: Text(
                                _isScanning
                                    ? context.l10n.stopScanning
                                    : context.l10n.findMeters,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (remembered.isNotEmpty) ...[
                      SizedBox(height: 24),
                      Text(
                        context.l10n.savedMeters,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      for (final dev in remembered)
                        Card.outlined(
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Icon(
                              dev.autoConnect ? Icons.bolt : Icons.star_outline,
                              color: colors.primary,
                            ),
                            title: Text(
                              dev.name.isEmpty ? 'Mooshimeter' : dev.name,
                            ),
                            subtitle: Text(
                              dev.autoConnect
                                  ? context.l10n.autoConnectEnabled
                                  : context.l10n.savedConnect,
                            ),
                            trailing: _isConnecting(dev.address)
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.chevron_right),
                            onTap: busy ? null : () => _connectRemembered(dev),
                          ),
                        ),
                    ],
                    if (_connectedDevices.isNotEmpty) ...[
                      SizedBox(height: 24),
                      Text(
                        context.l10n.knownDevices,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      for (final device in _connectedDevices)
                        Card.outlined(
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: colors.primary,
                            ),
                            title: Text(device.name ?? 'Mooshimeter'),
                            subtitle: Text(context.l10n.establishConnection),
                            trailing: Icon(Icons.chevron_right),
                            onTap: busy ? null : () => _selectDevice(device),
                          ),
                        ),
                    ],
                    SizedBox(height: 24),
                    Text(
                      context.l10n.nearbyMeters,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    if (_devices.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _isScanning
                              ? context.l10n.searchingMeters
                              : remembered.isNotEmpty
                              ? context.l10n.savedHint
                              : context.l10n.noMeters,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    for (final result in _devices)
                      Card.outlined(
                        child: DeviceTile(
                          name: result.device.name ?? 'Mooshimeter',
                          address: result.device.deviceId,
                          rssi: result.rssi,
                          isConnected:
                              provider.state == MmConnectionState.connected &&
                              provider.deviceId == result.device.deviceId,
                          isConnecting: _isConnecting(result.device.deviceId),
                          onTap: () {
                            if (!busy) _selectDevice(result.device);
                          },
                          isRemembered: settings.isRemembered(
                            result.device.deviceId.toLowerCase(),
                          ),
                          onRemember: () => _rememberDevice(result.device),
                          onForget: () => _forgetDevice(result.device.deviceId),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Connect to a remembered device by scanning for it.
  Future<void> _connectRemembered(RememberedDevice dev) async {
    _screenLog('>>> _connectRemembered START');
    _screenLog('    dev.name="${dev.name}" dev.addr="${dev.address}"');
    final target = dev.address.toLowerCase().replaceAll('_', '');
    _screenLog('    target address (cleaned): "$target"');

    if (_connectingAddress != null) return;
    if (mounted) {
      setState(() {
        _connectingAddress = target;
        _isScanning = true;
        _scanStatus = (context) => context.l10n.lookingFor(dev.name);
      });
    }

    // Check if already connected at OS level
    _screenLog(
      '    checking _connectedDevices (${_connectedDevices.length})...',
    );
    for (final cd in _connectedDevices) {
      final cdAddr = cd.deviceId.toLowerCase().replaceAll('_', '');
      _screenLog(
        '      cd="${cd.name}" addr="$cdAddr" match=${cdAddr == target}',
      );
      if (cdAddr == target) {
        _screenLog('    ✓ already connected at OS level, passing through');
        final connected = await widget.onDeviceSelected(cd);
        if (mounted) {
          setState(() {
            _connectingAddress = null;
            if (!connected) {
              _scanStatus = (context) => context.l10n.connectFailed;
            }
          });
        }
        _screenLog('<<< _connectRemembered (connected)');
        return;
      }
    }

    // Check if already connected via provider
    _screenLog('    checking BleProvider...');
    final provider = context.read<BleProvider>();
    final provAddr = provider.deviceId?.toLowerCase().replaceAll('_', '');
    _screenLog(
      '      provider.deviceId=${provider.deviceId != null} addr="$provAddr" state=${provider.state}',
    );
    if (provider.deviceId != null &&
        provAddr == target &&
        provider.state == MmConnectionState.connected) {
      _screenLog(
        '    ✓ provider has matching deviceId=$provAddr; connection flow is already complete',
      );
      _screenLog('<<< _connectRemembered (provider connected)');
      if (mounted) setState(() => _connectingAddress = null);
      return;
    }

    if (provider.deviceId != null &&
        provAddr == target &&
        provider.state == MmConnectionState.connecting) {
      _screenLog('    provider is already connecting to this device');
      if (mounted) setState(() => _connectingAddress = null);
      return;
    }

    BleDevice? found;

    try {
      _screenLog('    stopping any existing scan');
      await UniversalBle.stopScan().catchError(
        (_) => _screenLog('    stopScan error (ignored)'),
      );
      await Future.delayed(Duration(milliseconds: 200));
      _screenLog('    starting new scan (5s)');

      await UniversalBle.startScan();
      _screenLog('    scan started, listening for up to 7 seconds...');
      found = await Future.any<BleDevice?>([
        UniversalBle.scanStream
            .where(
              (bleDevice) => _normalizedAddress(bleDevice.deviceId) == target,
            )
            .map<BleDevice?>((device) => device)
            .first,
        Future<BleDevice?>.delayed(Duration(seconds: 7), () => null),
      ]);
      _screenLog('    scan loop ended, found=${found != null}');
    } catch (e) {
      _screenLog('>>> _connectRemembered FAILED: $e');
      debugPrint('Scan for remembered device failed: $e');
    } finally {
      _screenLog('    cleanup: stopping scan');
      await UniversalBle.stopScan().catchError((_) {});
      if (mounted) setState(() => _isScanning = false);
    }

    if (found != null) {
      _screenLog('    calling widget.onDeviceSelected("${found.name}")');
      if (mounted) {
        setState(
          () => _scanStatus = (context) => context.l10n.connectingTo(dev.name),
        );
      }
      final connected = await widget.onDeviceSelected(found);
      if (mounted && !connected) {
        setState(() => _scanStatus = (context) => context.l10n.connectFailed);
      }
      _screenLog('<<< _connectRemembered SUCCESS');
    } else {
      _screenLog('>>> _connectRemembered FAILED: no device found');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.meterNotFound(dev.name)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    if (mounted) setState(() => _connectingAddress = null);
  }

  Future<void> _rememberDevice(BleDevice device) async {
    _screenLog(
      '>>> _rememberDevice "${device.name ?? ""}" addr=${device.deviceId}',
    );
    final address = device.deviceId;
    final name = device.name ?? 'Unknown';
    await context.read<SettingsProvider>().rememberDevice(address, name);
    _screenLog('<<< _rememberDevice SUCCESS');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.deviceRemembered)));
    }
  }

  Future<void> _forgetDevice(String address) async {
    _screenLog('>>> _forgetDevice addr=$address');
    await context.read<SettingsProvider>().unrememberDevice(address);
    _screenLog('<<< _forgetDevice SUCCESS');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.forgotten)));
    }
  }
}

class _ScanData {
  final BleDevice device;
  final int rssi;
  _ScanData({required this.device, required this.rssi});
}
