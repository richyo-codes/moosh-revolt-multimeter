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
const String _screenLogPrefix = '[SCAN]';
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
  String _scanStatus = 'Tap to scan';
  int _deviceCount = 0;

  StreamSubscription? _scanSub;
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
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning...';
      _devices.clear();
      _scanningAddresses = [];
      _deviceCount = 0;
    });

    try {
      _screenLog('    cancelling existing _scanSub');
      await _scanSub?.cancel();
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
            _scanStatus = 'Found $_deviceCount device(s)';
            _screenLog('    _deviceCount=$_deviceCount');
          } else {
            _scanStatus = 'Scanning...';
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
        _scanStatus = 'Error: $e';
      });
      await _scanSub?.cancel();
      _scanSub = null;
    }

    _screenLog('    waiting 11s for scan timeout...');
    await Future.delayed(const Duration(seconds: 11));
    _screenLog('>>> timeout reached, calling _stopScan');
    await _stopScan();
  }

  Future<void> _stopScan() async {
    _screenLog('>>> _stopScan');
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      _screenLog('    calling UniversalBle.stopScan()');
      await UniversalBle.stopScan();
      _screenLog('<<< stopScan returned');
    } catch (_) {}
    setState(() {
      _isScanning = false;
      if (_deviceCount == 0) {
        _scanStatus = 'No devices found';
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
      _scanStatus = 'Connecting to ${device.name ?? 'Mooshimeter'}…';
    });
    _screenLog('    calling widget.onDeviceSelected');
    final connected = await widget.onDeviceSelected(device);
    if (!mounted) return;
    setState(() {
      _connectingAddress = null;
      if (!connected) _scanStatus = 'Could not connect — try again';
    });
    _screenLog('<<< _selectDevice connected=$connected');
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
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
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            onPressed: _isScanning ? _stopScan : _startScan,
            tooltip: _isScanning ? 'Stop Scan' : 'Scan',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.pushNamed(context, '/settings');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final remembered = settings.rememberedDevices;
          final provider = context.watch<BleProvider>();
          final connectedAddr = provider.deviceId?.toLowerCase() ?? '';
          return Column(
            children: [
              // Scan status bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(
                      _isScanning ? Icons.hourglass_empty : Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scanStatus,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_deviceCount > 0)
                      Chip(
                        label: Text('$_deviceCount found'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),

              // Connected devices section
              if (_connectedDevices.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.green.shade100,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bluetooth_connected,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_connectedDevices.length} online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: _connectedDevices.length > 2
                        ? 120
                        : _connectedDevices.length * 60.0,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _connectedDevices.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = _connectedDevices[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.green.shade200,
                          child: const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          (device.name ?? '').isNotEmpty
                              ? device.name!
                              : 'Unknown Device',
                        ),
                        subtitle: Text(
                          device.deviceId,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        trailing: const Chip(
                          label: Text(
                            'Connected',
                            style: TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green,
                        ),
                        onTap: () => _selectDevice(device),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],

              // Remembered devices section
              if (remembered.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.green.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Remembered',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${remembered.length} saved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: remembered.length > 3
                        ? 160
                        : remembered.length * 60.0,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: remembered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dev = remembered[index];
                      final hasAutoConnect = dev.autoConnect;
                      final connecting = _isConnecting(dev.address);
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: hasAutoConnect
                              ? Colors.amber.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            hasAutoConnect ? Icons.flash_on : Icons.bluetooth,
                            size: 16,
                            color: hasAutoConnect
                                ? Colors.amber.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          dev.name.isNotEmpty ? dev.name : 'Unknown Device',
                        ),
                        subtitle: Text(
                          dev.address,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                        trailing: connecting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : FilledButton.icon(
                                icon: Icon(
                                  hasAutoConnect
                                      ? Icons.flash_on
                                      : Icons.bluetooth_connected,
                                  size: 16,
                                ),
                                label: const Text('Connect'),
                                onPressed: _connectingAddress == null
                                    ? () => _connectRemembered(dev)
                                    : null,
                              ),
                        onTap: () => _connectRemembered(dev),
                      );
                    },
                  ),
                ),
              ],

              // Scan separator
              if (remembered.isNotEmpty) const Divider(height: 1),

              // Device list
              Expanded(
                child: _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_searching,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              remembered.isEmpty
                                  ? 'No devices detected'
                                  : 'No nearby devices detected',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              remembered.isEmpty
                                  ? 'Press Scan to find your Mooshimeter'
                                  : 'Use Connect above to find a saved meter',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _devices[index];
                          final addr = result.device.deviceId.toLowerCase();
                          final isConnected = connectedAddr == addr;
                          final isRemembered = settings.isRemembered(addr);
                          final devName = result.device.name ?? 'Unknown';
                          return DeviceTile(
                            name: devName,
                            address: result.device.deviceId,
                            rssi: result.rssi,
                            isConnected: isConnected,
                            isConnecting: _isConnecting(result.device.deviceId),
                            onTap: () => _selectDevice(result.device),
                            isRemembered: isRemembered,
                            onRemember: () => _rememberDevice(result.device),
                            onForget: () =>
                                _forgetDevice(result.device.deviceId),
                          );
                        },
                      ),
              ),
            ],
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
        _scanStatus = 'Looking for ${dev.name}…';
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
            if (!connected) _scanStatus = 'Could not connect — try again';
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
      await Future.delayed(const Duration(milliseconds: 200));
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
        Future<BleDevice?>.delayed(const Duration(seconds: 7), () => null),
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
      if (mounted) setState(() => _scanStatus = 'Connecting to ${dev.name}…');
      final connected = await widget.onDeviceSelected(found);
      if (mounted && !connected) {
        setState(() => _scanStatus = 'Could not connect — try again');
      }
      _screenLog('<<< _connectRemembered SUCCESS');
    } else {
      _screenLog('>>> _connectRemembered FAILED: no device found');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not find "${dev.name}" — is it nearby?'),
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
      ).showSnackBar(const SnackBar(content: Text('Device remembered')));
    }
  }

  Future<void> _forgetDevice(String address) async {
    _screenLog('>>> _forgetDevice addr=$address');
    await context.read<SettingsProvider>().unrememberDevice(address);
    _screenLog('<<< _forgetDevice SUCCESS');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device forgotten')));
    }
  }
}

class _ScanData {
  final BleDevice device;
  final int rssi;
  _ScanData({required this.device, required this.rssi});
}
