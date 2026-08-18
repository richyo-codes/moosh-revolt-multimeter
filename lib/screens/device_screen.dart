import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:provider/provider.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/models/remembered_device.dart';
import 'package:moosh_revolt/widgets/readings_display.dart';
import 'package:moosh_revolt/widgets/realtime_chart.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/screens/graph_screen.dart';
import 'package:moosh_revolt/widgets/mooshrevolt_mark.dart';

/// The device screen showing live readings and controls.
class DeviceScreen extends StatefulWidget {
  final BleDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  ChannelMode _ch1Mode = ChannelMode.current;
  ChannelMode _ch2Mode = ChannelMode.voltage;
  int _sampleRate = 125;
  late final BleProvider _bleProvider;
  late final SettingsProvider _settingsProvider;

  final List<LinePoint> _ch1Points = [];
  final List<LinePoint> _ch2Points = [];
  int _pointCount = 0; // updated dynamically, not final
  bool _providerListenerAttached = false;
  Timer? _sampleDebounce;
  double? _graphStartTimestamp;
  DisplayUnit _ch1DisplayUnit = DisplayUnit.auto;
  DisplayUnit _ch2DisplayUnit = DisplayUnit.auto;
  int? _voltageRangeIndex;
  bool _showCh1 = true;
  bool _showCh2 = true;
  GraphStyle _graphStyle = GraphStyle.dualAxis;
  bool _continuityToneEnabled = false;
  bool _ch1MinMaxTracking = false;
  bool _ch2MinMaxTracking = false;
  double? _ch1Minimum;
  double? _ch1Maximum;
  double? _ch2Minimum;
  double? _ch2Maximum;
  DateTime? _continuityReadyAt;
  String? _continuityTonePath;
  Process? _continuityToneProcess;
  bool _continuityToneWanted = false;
  final GlobalKey _captureKey = GlobalKey();

  // --- Device screen logging ---
  final String _devLogPrefix = '[DEV]';
  void _devLog(String msg) => debugPrint('$_devLogPrefix $msg');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_providerListenerAttached) {
      _bleProvider = context.read<BleProvider>();
      _settingsProvider = context.read<SettingsProvider>();
      _sampleRate = _settingsProvider.sampleRate;
      _bleProvider.addListener(_onBleProviderChanged);
      _providerListenerAttached = true;
    }
    _devLog(
      'didChangeDependencies — provider=${_bleProvider.state} deviceId=${_bleProvider.deviceId}',
    );
  }

  @override
  void initState() {
    super.initState();
    _devLog(
      'initState — widget.device="${widget.device.name}" addr=${widget.device.deviceId}',
    );

    // Connect via the provider (no manual stream management)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _devLog('addPostFrameCallback — calling _connectAndRemember');
      _connectAndRemember();
    });
  }

  Future<void> _connectAndRemember() async {
    _devLog('>>> _connectAndRemember START');
    _devLog(
      '    provider state=${_bleProvider.state} deviceId=${_bleProvider.deviceId}',
    );

    // If already connected to this device, skip connection.
    // This handles the case where HomePage._doConnect already connected.
    final isSameDevice =
        _bleProvider.deviceId != null &&
        _bleProvider.deviceId == widget.device.deviceId;
    _devLog('    isSameDevice=$isSameDevice');

    if (_bleProvider.state == MmConnectionState.connected && isSameDevice) {
      _devLog('✓ Already connected to same device, skipping connect');
      // Still remember the device
      final name = widget.device.name ?? 'Unknown';
      final address = widget.device.deviceId;
      _devLog('    remembering device...');
      await _settingsProvider.rememberDevice(address, name);
      _devLog('<<< _connectAndRemember (skipped, already connected)');
      return;
    }

    // If already connecting, don't start another connect.
    if (_bleProvider.state == MmConnectionState.connecting) {
      _devLog('✓ Already connecting, waiting');
      _devLog('<<< _connectAndRemember (skipped, connecting)');
      return;
    }

    _devLog('    calling _bleProvider.connect("${widget.device.name ?? ""}")');
    final success = await _bleProvider.connect(
      widget.device,
      sampleRate: _settingsProvider.sampleRate,
    );
    _devLog(
      '    connect returned success=$success, state=${_bleProvider.state}',
    );

    if (success && mounted) {
      // Remember the device so it can auto-connect next time
      final name = widget.device.name ?? 'Unknown';
      final address = widget.device.deviceId;
      _devLog('    remembering device...');
      await _settingsProvider.rememberDevice(address, name);
      _devLog('<<< _connectAndRemember SUCCESS');
    } else {
      _devLog(
        '>>> _connectAndRemember FAILED (success=$success mounted=$mounted)',
      );
    }
  }

  @override
  void dispose() {
    _devLog('>>> dispose');
    _sampleDebounce?.cancel();
    _continuityToneWanted = false;
    _stopContinuityTone();
    if (_providerListenerAttached) {
      _bleProvider.removeListener(_onBleProviderChanged);
    }
    _bleProvider.disconnect();
    super.dispose();
    _devLog('<<< dispose');
  }

  @override
  Widget build(BuildContext context) {
    final compactAppBar = MediaQuery.sizeOf(context).width < 600;
    return Consumer2<BleProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final isConnected = provider.state == MmConnectionState.connected;
        final readings = provider.latestReadings;
        final hasFreshReadings = provider.hasFreshReadings;
        final ch1Value = hasFreshReadings ? readings?.ch1Value ?? 0.0 : 0.0;
        final ch2Value = hasFreshReadings ? readings?.ch2Value ?? 0.0 : 0.0;
        final rssi = provider.rssi;
        final battery = provider.battery;
        final ch1OutOfRange =
            isConnected && ch1Value.abs() > 1.2 * Channel.ch1.max;
        final ch2OutOfRange =
            isConnected && ch2Value.abs() > 1.2 * Channel.ch2.max;

        return RepaintBoundary(
          key: _captureKey,
          child: Scaffold(
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
              elevation: 0,
              actions: [
                _connectionStatusWidget(provider.state, compact: compactAppBar),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showDeviceSettings,
                  tooltip: 'Meter settings',
                ),
                PopupMenuButton<String>(
                  onSelected: _handleMenu,
                  itemBuilder: (_) => [
                    if (isConnected)
                      const PopupMenuItem(
                        value: 'graph',
                        child: Text('Graph View'),
                      ),
                    if (isConnected)
                      PopupMenuItem(
                        value: 'graph-style',
                        child: Text('Graph style: $_graphStyleLabel'),
                      ),
                    if (isConnected)
                      PopupMenuItem(
                        value: 'sample-rate',
                        child: Text('Sample rate: $_sampleRate Hz'),
                      ),
                    if (isConnected)
                      const PopupMenuItem(
                        value: 'clear-graph',
                        child: Text('Clear graph'),
                      ),
                    const PopupMenuItem(
                      value: 'copy-cli',
                      child: Text('Copy CSV logger command'),
                    ),
                    const PopupMenuItem(
                      value: 'snapshot',
                      child: Text('Save data snapshot'),
                    ),
                    const PopupMenuItem(
                      value: 'screenshot',
                      child: Text('Save screenshot'),
                    ),
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
            body: isConnected
                ? _buildReadingsTab(
                    isConnected: true,
                    ch1Value: ch1Value,
                    ch2Value: ch2Value,
                    rssi: rssi,
                    battery: battery,
                    ch1OutOfRange: ch1OutOfRange,
                    ch2OutOfRange: ch2OutOfRange,
                    provider: provider,
                    showFloatingReadings: settings.showFloatingReadings,
                    hasFreshReadings: hasFreshReadings,
                  )
                : _buildDisconnectedState(provider.state),
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedState(MmConnectionState state) {
    final connecting = state == MmConnectionState.connecting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connecting ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              connecting ? 'Connecting to meter…' : 'Meter disconnected',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (!connecting) ...[
              const SizedBox(height: 8),
              Text(
                'The live readings have been cleared. Reconnect to resume sampling.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _connectAndRemember,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _connectionStatusWidget(
    MmConnectionState state, {
    required bool compact,
  }) {
    String status;
    Color color;
    IconData icon;

    switch (state) {
      case MmConnectionState.connecting:
        status = 'Connecting...';
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case MmConnectionState.connected:
        status = 'Connected';
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case MmConnectionState.disconnecting:
        status = 'Disconnecting...';
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case MmConnectionState.disconnected:
        status = 'Disconnected';
        color = Colors.red;
        icon = Icons.bluetooth_disabled;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(status, style: TextStyle(color: color, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingsTab({
    required bool isConnected,
    required double ch1Value,
    required double ch2Value,
    required int rssi,
    required double battery,
    required bool ch1OutOfRange,
    required bool ch2OutOfRange,
    required BleProvider provider,
    required bool showFloatingReadings,
    required bool hasFreshReadings,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscapeLayout =
            constraints.maxWidth >= 700 &&
            constraints.maxWidth > constraints.maxHeight;
        final portraitReadingsHeight = math.min(
          330.0,
          math.max(272.0, constraints.maxHeight * 0.25),
        );
        final readings = ReadingsDisplay(
          ch1Value: ch1Value,
          ch2Value: ch2Value,
          ch1Mode: _ch1Mode,
          ch2Mode: _ch2Mode,
          ch1OutOfRange: ch1OutOfRange,
          ch2OutOfRange: ch2OutOfRange,
          ch1DisplayUnit: _ch1DisplayUnit,
          ch2DisplayUnit: _ch2DisplayUnit,
          onCh1DisplayUnitChanged: (unit) =>
              setState(() => _ch1DisplayUnit = unit),
          onCh2DisplayUnitChanged: (unit) =>
              setState(() => _ch2DisplayUnit = unit),
          ch1MinMaxTracking: _ch1MinMaxTracking,
          ch2MinMaxTracking: _ch2MinMaxTracking,
          ch1Minimum: _ch1Minimum,
          ch1Maximum: _ch1Maximum,
          ch2Minimum: _ch2Minimum,
          ch2Maximum: _ch2Maximum,
          onCh1MinMaxChanged: (enabled) => setState(() {
            _ch1MinMaxTracking = enabled;
            _resetCh1MinMax();
          }),
          onCh2MinMaxChanged: (enabled) => setState(() {
            _ch2MinMaxTracking = enabled;
            _resetCh2MinMax();
          }),
          onCh1Configure: () => _showChannelConfigurator(0, provider),
          onCh2Configure: () => _showChannelConfigurator(1, provider),
          ch1PossiblyFloating: _isPossiblyFloating(_ch1Points, 0.0001),
          ch2PossiblyFloating: _isPossiblyFloating(_ch2Points, 0.005),
          ch1Units: _channelUnits(0, _ch1Mode),
          ch1Max: _channelMax(0, _ch1Mode),
          ch2Units: _channelUnits(1, _ch2Mode),
          ch2Max: _channelMax(1, _ch2Mode),
          compactLayout: landscapeLayout && constraints.maxHeight < 500,
          stackedLayout: landscapeLayout,
          showFloatingValues: showFloatingReadings,
          hasFreshSample: hasFreshReadings,
          showCh1: _showCh1,
          showCh2: _showCh2,
        );
        final chart = Padding(
          padding: const EdgeInsets.all(12),
          child: RealtimeChart(
            ch1Points: _showCh1 ? _ch1Points : const [],
            ch2Points: _showCh2 ? _ch2Points : const [],
            ch1Label: 'CH1 · ${_ch1Mode.label} (${_channelUnits(0, _ch1Mode)})',
            ch2Label: 'CH2 · ${_ch2Mode.label} (${_channelUnits(1, _ch2Mode)})',
            style: _graphStyle,
          ),
        );
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: landscapeLayout
                    ? Row(
                        key: const ValueKey('landscape-meter-layout'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 4, child: readings),
                          Expanded(flex: 6, child: chart),
                        ],
                      )
                    : Column(
                        key: const ValueKey('portrait-meter-layout'),
                        children: [
                          SizedBox(
                            height: portraitReadingsHeight,
                            child: readings,
                          ),
                          Expanded(child: chart),
                        ],
                      ),
              ),
              _buildSampleFooter(battery: battery, rssi: rssi),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSampleFooter({required double battery, required int rssi}) {
    final colors = Theme.of(context).colorScheme;
    final batteryPercent = _batteryPercent(battery);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 4,
          children: [
            if (rssi > -999) ...[
              _footerPill(
                icon: Icons.signal_cellular_alt,
                label: '$rssi dBm',
                colors: colors,
              ),
            ],
            Tooltip(
              message:
                  '${battery.toStringAsFixed(2)} V measured across two AA cells',
              child: _footerPill(
                icon: _batteryIcon(batteryPercent),
                label: 'Battery $batteryPercent%',
                colors: colors,
              ),
            ),
            _footerPill(
              icon: Icons.data_usage,
              label: '$_pointCount samples',
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  int _batteryPercent(double voltage) {
    // Two AA cells: roughly 2.0 V depleted through 3.2 V freshly installed.
    return (((voltage - 2.0) / 1.2) * 100).round().clamp(0, 100);
  }

  IconData _batteryIcon(int percent) => switch (percent) {
    > 85 => Icons.battery_full,
    > 55 => Icons.battery_5_bar,
    > 30 => Icons.battery_3_bar,
    > 10 => Icons.battery_1_bar,
    _ => Icons.battery_alert,
  };

  Widget _footerPill({
    required IconData icon,
    required String label,
    required ColorScheme colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _showChannelConfigurator(
    int channel,
    BleProvider provider,
  ) async {
    final isCh1 = channel == 0;
    final channelName = isCh1 ? 'CH1' : 'CH2';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.85,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final mode = isCh1 ? _ch1Mode : _ch2Mode;
                final isVisible = isCh1 ? _showCh1 : _showCh2;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$channelName configuration',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCh1
                          ? 'Current, resistance, and auxiliary measurements'
                          : 'Voltage and auxiliary measurements',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show channel'),
                      subtitle: const Text(
                        'Include this channel in readings and graph',
                      ),
                      value: isVisible,
                      onChanged: (visible) {
                        setState(() {
                          if (isCh1) {
                            _showCh1 = visible;
                          } else {
                            _showCh2 = visible;
                          }
                        });
                        setSheetState(() {});
                      },
                    ),
                    if (isCh1 && mode == ChannelMode.resistance) ...[
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          _continuityToneEnabled
                              ? Icons.volume_up
                              : Icons.volume_off,
                        ),
                        title: const Text('Continuity tone'),
                        subtitle: const Text(
                          'Play a continuous tone below 50 Ω',
                        ),
                        value: _continuityToneEnabled,
                        onChanged: (enabled) {
                          setState(() {
                            _continuityToneEnabled = enabled;
                            _continuityReadyAt = enabled
                                ? DateTime.now().add(const Duration(seconds: 1))
                                : null;
                          });
                          if (!enabled) {
                            _continuityToneWanted = false;
                            _stopContinuityTone();
                          }
                          setSheetState(() {});
                        },
                      ),
                    ],
                    const Divider(),
                    Text(
                      'Measurement',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _channelModesFor(channel).map((candidate) {
                        return ChoiceChip(
                          label: Text(candidate.label),
                          selected: mode == candidate,
                          onSelected: (selected) async {
                            if (!selected) return;
                            await _setChannelMode(channel, candidate, provider);
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Input range',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCh1
                          ? _ch1RangeDescription(mode)
                          : 'Auto keeps normal measurements on the 60 V input and changes only when needed.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (isCh1)
                      ChoiceChip(
                        label: Text(_ch1RangeLabel(mode)),
                        selected: true,
                        onSelected: (_) => provider.setRange(0, 0),
                      )
                    else if (mode == ChannelMode.internalTemperature)
                      Text(
                        'Temperature mode does not use a voltage range.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Auto (recommended)'),
                            selected: _voltageRangeIndex == null,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _voltageRangeIndex = null);
                              setSheetState(() {});
                              provider.setVoltageRange(null);
                            },
                          ),
                          for (final range in [
                            (0, '60 V input'),
                            (1, '600 V input'),
                          ])
                            ChoiceChip(
                              label: Text(range.$2),
                              selected: _voltageRangeIndex == range.$1,
                              onSelected: (selected) {
                                if (!selected) return;
                                setState(() => _voltageRangeIndex = range.$1);
                                setSheetState(() {});
                                provider.setVoltageRange(range.$1);
                              },
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setChannelMode(
    int channel,
    ChannelMode mode,
    BleProvider provider,
  ) async {
    if (channel == 0 && _ch1Mode == ChannelMode.resistance) {
      _continuityToneWanted = false;
      _stopContinuityTone();
      await provider.setContinuityEnabled(false);
      if (!mounted) return;
      setState(() {
        _continuityToneEnabled = false;
        _continuityReadyAt = null;
      });
    }
    if (channel == 0 && mode == ChannelMode.resistance) {
      _sampleDebounce?.cancel();
      await provider.setContinuityEnabled(true);
    } else if (mode.hardwareIndex >= 0) {
      await provider.setInputMode(channel, mode.hardwareIndex);
    }
    if (!mounted) return;
    setState(() {
      if (channel == 0) {
        _ch1Mode = mode;
      } else {
        _ch2Mode = mode;
      }
    });
  }

  List<ChannelMode> _channelModesFor(int channel) => channel == 0
      ? const [
          ChannelMode.current,
          ChannelMode.currentAc,
          ChannelMode.internalTemperature,
          ChannelMode.auxiliaryVoltageDc,
          ChannelMode.auxiliaryVoltageAc,
          ChannelMode.resistance,
          ChannelMode.diode,
        ]
      : const [
          ChannelMode.voltage,
          ChannelMode.voltageAc,
          ChannelMode.internalTemperature,
        ];

  String _channelUnits(int channel, ChannelMode mode) {
    if (mode == ChannelMode.internalTemperature) return '°C';
    if (channel == 0 &&
        (mode == ChannelMode.auxiliaryVoltageDc ||
            mode == ChannelMode.auxiliaryVoltageAc)) {
      return 'V';
    }
    return channel == 0 ? 'A' : 'V';
  }

  double _channelMax(int channel, ChannelMode mode) {
    if (mode == ChannelMode.resistance) return 1000;
    if (mode == ChannelMode.internalTemperature) return 100;
    if (channel == 0 &&
        (mode == ChannelMode.auxiliaryVoltageDc ||
            mode == ChannelMode.auxiliaryVoltageAc)) {
      return 600;
    }
    return channel == 0 ? 10 : 600;
  }

  String _ch1RangeLabel(ChannelMode mode) => switch (mode) {
    ChannelMode.current => '10 A input',
    ChannelMode.resistance => '1 kΩ input',
    _ => 'Default input range',
  };

  String _ch1RangeDescription(ChannelMode mode) => switch (mode) {
    ChannelMode.current => 'CH1 current uses the 10 A input range.',
    ChannelMode.resistance =>
      'Resistance and continuity use the 1 kΩ input range.',
    _ => 'This measurement uses the meter default range.',
  };

  String get _graphStyleLabel => switch (_graphStyle) {
    GraphStyle.split => 'Split',
    GraphStyle.dualAxis => 'Dual axis',
    GraphStyle.sharedAxis => 'Shared',
  };

  void _onBleProviderChanged() {
    if (!mounted) return;
    if (_bleProvider.state != MmConnectionState.connected) {
      _sampleDebounce?.cancel();
      // Keep historical samples visible while the live reading is stale or
      // disconnected. Explicit Clear and intentional mode changes reset it.
      return;
    }
    if (_bleProvider.latestReadings == null) {
      // The freshness watchdog intentionally expires the live value. It must
      // not erase the historical graph when one BLE sample is missed.
      return;
    }
    // Capture at a bounded rate, while retaining the latest sample. A trailing
    // debounce would continually restart when the meter (or mock provider)
    // publishes faster than its delay, leaving the graph permanently empty.
    if (_sampleDebounce?.isActive ?? false) return;
    _sampleDebounce = Timer(
      const Duration(milliseconds: 30),
      _captureLatestReading,
    );
  }

  void _captureLatestReading() {
    if (!mounted) return;
    final reading = _bleProvider.latestReadings;
    if (reading == null) return;
    _graphStartTimestamp ??= reading.timestamp;
    final elapsed = reading.timestamp - _graphStartTimestamp!;
    if (_ch1Points.isNotEmpty && elapsed <= _ch1Points.last.x) return;
    setState(() {
      _ch1Points.add(LinePoint(elapsed, reading.ch1Value));
      _ch2Points.add(LinePoint(elapsed, reading.ch2Value));
      if (_ch1MinMaxTracking) {
        _ch1Minimum = _ch1Minimum == null
            ? reading.ch1Value
            : math.min(_ch1Minimum!, reading.ch1Value);
        _ch1Maximum = _ch1Maximum == null
            ? reading.ch1Value
            : math.max(_ch1Maximum!, reading.ch1Value);
      }
      if (_ch2MinMaxTracking) {
        _ch2Minimum = _ch2Minimum == null
            ? reading.ch2Value
            : math.min(_ch2Minimum!, reading.ch2Value);
        _ch2Maximum = _ch2Maximum == null
            ? reading.ch2Value
            : math.max(_ch2Maximum!, reading.ch2Value);
      }
      _pointCount++;
      final maxPoints = _settingsProvider.graphMaxPoints;
      if (_ch1Points.length > maxPoints) {
        _ch1Points.removeAt(0);
        _ch2Points.removeAt(0);
      }
    });
    final continuityReady =
        _continuityReadyAt != null &&
        !DateTime.now().isBefore(_continuityReadyAt!);
    final shouldSound =
        _continuityToneEnabled &&
        _ch1Mode == ChannelMode.resistance &&
        continuityReady &&
        reading.ch1Value >= 0 &&
        reading.ch1Value < 50;
    if (shouldSound) {
      _continuityToneWanted = true;
      unawaited(_startContinuityTone());
    } else {
      _continuityToneWanted = false;
      _stopContinuityTone();
    }
  }

  Future<void> _startContinuityTone() async {
    if (_continuityToneProcess != null ||
        !_continuityToneWanted ||
        !Platform.isLinux) {
      return;
    }
    try {
      _continuityTonePath ??= await _writeContinuityTone();
      if (!_continuityToneWanted) return;
      final player = await Process.start('paplay', [_continuityTonePath!]);
      if (!_continuityToneWanted) {
        player.kill();
        return;
      }
      _continuityToneProcess = player;
      unawaited(
        player.exitCode.whenComplete(() {
          if (identical(_continuityToneProcess, player)) {
            _continuityToneProcess = null;
          }
        }),
      );
    } catch (error) {
      _devLog('continuity tone failed: $error');
    }
  }

  void _stopContinuityTone() {
    final player = _continuityToneProcess;
    _continuityToneProcess = null;
    player?.kill();
  }

  Future<String> _writeContinuityTone() async {
    const sampleRate = 44100;
    const durationMs = 60000;
    const frequency = 880.0;
    final sampleCount = sampleRate * durationMs ~/ 1000;
    final pcm = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      // Short fades avoid an audible click when the continuity process starts
      // or stops; the rest is a steady, continuous 880 Hz tone.
      final envelope = math.min(
        1.0,
        math.min(i / 220, (sampleCount - i) / 220),
      );
      pcm[i] =
          (math.sin(2 * math.pi * frequency * i / sampleRate) *
                  12000 *
                  envelope)
              .round();
    }

    final dataLength = pcm.lengthInBytes;
    final wav = BytesBuilder(copy: false)
      ..add(ascii.encode('RIFF'))
      ..add(_littleEndian32(36 + dataLength))
      ..add(ascii.encode('WAVEfmt '))
      ..add(_littleEndian32(16))
      ..add(_littleEndian16(1))
      ..add(_littleEndian16(1))
      ..add(_littleEndian32(sampleRate))
      ..add(_littleEndian32(sampleRate * 2))
      ..add(_littleEndian16(2))
      ..add(_littleEndian16(16))
      ..add(ascii.encode('data'))
      ..add(_littleEndian32(dataLength))
      ..add(Uint8List.view(pcm.buffer));
    final file = File(
      '${Directory.systemTemp.path}/mooshimeter-continuity.wav',
    );
    await file.writeAsBytes(wav.takeBytes(), flush: true);
    return file.path;
  }

  Uint8List _littleEndian16(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

  Uint8List _littleEndian32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

  bool _isPossiblyFloating(List<LinePoint> points, double nearZeroThreshold) {
    if (points.length < 8) return false;
    final recent = points.sublist(points.length - 8);
    return recent.every((point) => point.y.abs() < nearZeroThreshold);
  }

  void _clearGraph() {
    setState(() {
      _ch1Points.clear();
      _ch2Points.clear();
      _pointCount = 0;
      _graphStartTimestamp = null;
      _resetMinMax();
    });
  }

  void _resetMinMax() {
    _resetCh1MinMax();
    _resetCh2MinMax();
  }

  void _resetCh1MinMax() {
    _ch1Minimum = null;
    _ch1Maximum = null;
  }

  void _resetCh2MinMax() {
    _ch2Minimum = null;
    _ch2Maximum = null;
  }

  Future<Directory> _recordsDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/Mooshimeter');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _timestampName() =>
      DateTime.now().toIso8601String().replaceAll(':', '-');

  Future<void> _saveDataSnapshot() async {
    final rows = <String>['elapsed_s,current_a,voltage_v'];
    for (var i = 0; i < _ch1Points.length; i++) {
      rows.add('${_ch1Points[i].x},${_ch1Points[i].y},${_ch2Points[i].y}');
    }
    await _saveRows(rows, 'snapshot');
  }

  Future<void> _saveRows(List<String> rows, String kind) async {
    if (rows.length <= 1) {
      _showMessage('No samples to save');
      return;
    }
    final directory = await _recordsDirectory();
    final file = File(
      '${directory.path}/mooshimeter_${kind}_${_timestampName()}.csv',
    );
    await file.writeAsString('${rows.join('\n')}\n');
    _showMessage('Saved ${file.path}');
  }

  Future<void> _saveScreenshot() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final directory = await _recordsDirectory();
    final file = File('${directory.path}/mooshimeter_${_timestampName()}.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    _showMessage('Saved ${file.path}');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSettingsTab() {
    return Consumer<BleProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Sample Rate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [125, 250, 500, 1000, 2000, 4000, 8000].map((rate) {
                return ChoiceChip(
                  label: Text('$rate Hz'),
                  selected: _sampleRate == rate,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _sampleRate = rate);
                      _settingsProvider.sampleRate = rate;
                      provider.setSampleRate(rate);
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(height: 32),
            const Text(
              'SD Card Logging',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                provider.sdCardReady ? Icons.sd_card : Icons.sd_card_alert,
                color: provider.sdCardReady ? Colors.green : Colors.orange,
              ),
              title: Text(provider.sdCardStatusLabel),
              subtitle: Text(
                provider.sdLogStatus == null
                    ? 'Tap refresh to check the meter’s microSD card.'
                    : provider.sdCardReady
                    ? 'Card detected. The meter can log while disconnected.'
                    : 'Insert a FAT/FAT32 microSD card and refresh.',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh SD-card status',
                onPressed: () => unawaited(provider.refreshSdLogging()),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Log measurements to SD card'),
              subtitle: const Text('Logging continues after disconnecting.'),
              value: provider.sdLoggingEnabled,
              onChanged: provider.sdCardReady
                  ? (enabled) =>
                        unawaited(provider.setSdLoggingEnabled(enabled))
                  : null,
            ),
            if (provider.sdCardReady) ...[
              const Text('Logging interval'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1, 10, 60].map((seconds) {
                  return ChoiceChip(
                    label: Text(seconds == 1 ? '1 second' : '$seconds seconds'),
                    selected: provider.sdLogIntervalSeconds == seconds,
                    onSelected: (selected) {
                      if (selected) {
                        unawaited(provider.setSdLogIntervalSeconds(seconds));
                      }
                    },
                  );
                }).toList(),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Set a safe fixed input range before logging; the meter does not autorange while logging.',
                ),
              ),
            ],
            const Divider(height: 32),
            // Device management
            const Text(
              'Device',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<RememberedDevice?>(
              future: _fetchRemembered(),
              builder: (context, snapshot) {
                final isRemembered = snapshot.data != null;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        isRemembered
                            ? 'Remembered: ${snapshot.data!.name} (${snapshot.data!.address})'
                            : 'Not remembered',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    isRemembered
                        ? TextButton(
                            onPressed: () async {
                              final settings = context.read<SettingsProvider>();
                              final address = widget.device.deviceId;
                              final devName = snapshot.data?.name ?? 'Device';
                              await settings.unrememberDevice(address);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$devName forgotten')),
                                );
                              }
                            },
                            child: const Text('Forget'),
                          )
                        : TextButton(
                            onPressed: () async {
                              final settings = context.read<SettingsProvider>();
                              final address = widget.device.deviceId;
                              final name = widget.device.name ?? 'Unknown';
                              await settings.rememberDevice(address, name);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device remembered'),
                                  ),
                                );
                              }
                            },
                            child: const Text('Remember'),
                          ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeviceSettings() {
    unawaited(_bleProvider.refreshSdLogging());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Device settings')),
          body: _buildSettingsTab(),
        ),
      ),
    );
  }

  Future<RememberedDevice?> _fetchRemembered() async {
    final settings = context.read<SettingsProvider>();
    final address = widget.device.deviceId;
    return settings.getRemembered(address);
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'graph':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GraphScreen(
              ch1Points: List.of(_ch1Points),
              ch2Points: List.of(_ch2Points),
            ),
          ),
        );
        break;
      case 'copy-cli':
        unawaited(_copyCliCommand());
        break;
      case 'graph-style':
        unawaited(_showGraphStylePicker());
        break;
      case 'sample-rate':
        unawaited(_showSampleRatePicker());
        break;
      case 'clear-graph':
        _clearGraph();
        break;
      case 'snapshot':
        unawaited(_saveDataSnapshot());
        break;
      case 'screenshot':
        unawaited(_saveScreenshot());
        break;
      case 'disconnect':
        context.read<BleProvider>().disconnect();
        break;
    }
  }

  Future<void> _showGraphStylePicker() async {
    final style = await showDialog<GraphStyle>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Graph style'),
        children: GraphStyle.values
            .map(
              (style) => ListTile(
                leading: Icon(
                  style == _graphStyle
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_graphStyleLabelFor(style)),
                onTap: () => Navigator.pop(context, style),
              ),
            )
            .toList(),
      ),
    );
    if (style != null && mounted) setState(() => _graphStyle = style);
  }

  Future<void> _showSampleRatePicker() async {
    final rate = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sample rate'),
        children: [125, 250, 500, 1000, 2000, 4000, 8000]
            .map(
              (rate) => ListTile(
                leading: Icon(
                  rate == _sampleRate
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text('$rate Hz'),
                onTap: () => Navigator.pop(context, rate),
              ),
            )
            .toList(),
      ),
    );
    if (rate == null || !mounted) return;
    setState(() => _sampleRate = rate);
    _settingsProvider.sampleRate = rate;
    await _bleProvider.setSampleRate(rate);
  }

  String _graphStyleLabelFor(GraphStyle style) => switch (style) {
    GraphStyle.split => 'Split channels',
    GraphStyle.dualAxis => 'Dual axis',
    GraphStyle.sharedAxis => 'Shared axis',
  };

  Future<void> _copyCliCommand() async {
    final channel = switch ((_showCh1, _showCh2)) {
      (true, true) => 'both',
      (true, false) => 'ch1',
      (false, true) => 'ch2',
      (false, false) => null,
    };
    if (channel == null) {
      _showMessage(
        'Enable at least one channel before copying a logger command',
      );
      return;
    }
    final command =
        'dart run tool/mooshimeter_log.dart --device ${widget.device.deviceId} '
        '--channel $channel --rate $_sampleRate --output readings.csv';
    await Clipboard.setData(ClipboardData(text: command));
    _showMessage('CSV logger command copied');
  }
}
