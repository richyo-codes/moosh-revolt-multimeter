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
import 'package:moosh_revolt/widgets/resizable_split.dart';
import 'package:mooshimeter_ble/mooshimeter_ble.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/services/continuity_tone.dart';
import 'package:moosh_revolt/services/csv_recorder.dart';
import 'package:moosh_revolt/screens/settings_screen.dart';
import 'package:moosh_revolt/widgets/mooshrevolt_mark.dart';

/// The device screen showing live readings and controls.
class DeviceScreen extends StatefulWidget {
  final BleDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with WidgetsBindingObserver {
  late final BleProvider _bleProvider;

  /// The channel whose configuration is docked beside the meter, if any.
  int? _configChannel;
  late final SettingsProvider _settingsProvider;

  final List<LinePoint> _ch1Points = [];
  final List<LinePoint> _ch2Points = [];
  int _pointCount = 0; // updated dynamically, not final
  bool _providerListenerAttached = false;
  Timer? _sampleDebounce;
  double? _graphStartTimestamp;
  // Screen preferences live in [SettingsProvider], so every change is saved
  // and restored on the next start.
  DisplayUnit get _ch1DisplayUnit => _settingsProvider.displayUnit(0);
  set _ch1DisplayUnit(DisplayUnit unit) =>
      _settingsProvider.setDisplayUnit(0, unit);
  DisplayUnit get _ch2DisplayUnit => _settingsProvider.displayUnit(1);
  set _ch2DisplayUnit(DisplayUnit unit) =>
      _settingsProvider.setDisplayUnit(1, unit);
  bool get _showCh1 => _settingsProvider.showChannel(0);
  set _showCh1(bool visible) => _settingsProvider.setShowChannel(0, visible);
  bool get _showCh2 => _settingsProvider.showChannel(1);
  set _showCh2(bool visible) => _settingsProvider.setShowChannel(1, visible);
  GraphStyle get _graphStyle =>
      GraphStyle.values
          .where((style) => style.name == _settingsProvider.graphStyle)
          .firstOrNull ??
      GraphStyle.dualAxis;
  set _graphStyle(GraphStyle style) =>
      _settingsProvider.graphStyle = style.name;
  bool get _continuityGraph => _settingsProvider.continuityGraph;
  set _continuityGraph(bool enabled) =>
      _settingsProvider.continuityGraph = enabled;
  bool _continuityToneEnabled = false;
  bool _ch1MinMaxTracking = false;
  bool _ch2MinMaxTracking = false;
  double? _ch1Minimum;
  // Running sums for the tracked averages.
  double _ch1Sum = 0;
  int _ch1Count = 0;
  double _ch2Sum = 0;
  int _ch2Count = 0;
  double? _ch1Maximum;
  double? _ch2Minimum;
  double? _ch2Maximum;
  DateTime? _continuityReadyAt;
  String? _continuityTonePath;
  bool _continuityToneWanted = false;
  final ContinuityTone _continuityTone = ContinuityTone();
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
      _bleProvider.addListener(_onBleProviderChanged);
      _providerListenerAttached = true;
      // Restore a saved tone; in resistance mode it holds the 1 kΩ range.
      final toneChannel = _toneChannel;
      if (_settingsProvider.continuityTone && toneChannel != null) {
        _setContinuityToneEnabled(true);
        if (_mode(toneChannel) == ChannelMode.resistance) {
          unawaited(_bleProvider.setRange(toneChannel, 0));
        }
      }
    }
    _devLog(
      'didChangeDependencies — provider=${_bleProvider.state} deviceId=${_bleProvider.deviceId}',
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _sampleDebounce?.cancel();
    _continuityToneWanted = false;
    _continuityTone.release();
    if (_providerListenerAttached) {
      _bleProvider.removeListener(_onBleProviderChanged);
    }
    _bleProvider.disconnect();
    super.dispose();
    _devLog('<<< dispose');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Desktop windows become "inactive" whenever they lose focus, while the
    // user is often looking at the circuit; only silence a backgrounded app.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _continuityToneWanted = false;
      _stopContinuityTone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactAppBar = MediaQuery.sizeOf(context).width < 600;
    return Consumer2<BleProvider, SettingsProvider>(
      builder: (context, provider, settings, child) {
        final isConnected = provider.state == MmConnectionState.connected;
        final readings = provider.latestReadings;
        final hasFreshReadings = provider.hasFreshReadings;
        final ch1Display = hasFreshReadings && readings != null
            ? _displayValue(readings, 0)
            : 0.0;
        final ch2Display = hasFreshReadings && readings != null
            ? _displayValue(readings, 1)
            : 0.0;
        final ch1Value = ch1Display.isNaN ? 0.0 : ch1Display;
        final ch2Value = ch2Display.isNaN ? 0.0 : ch2Display;
        final rssi = provider.rssi;
        final battery = provider.battery;
        final ch1OutOfRange = isConnected && ch1Display.isNaN;
        final ch2OutOfRange = isConnected && ch2Display.isNaN;

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
                if (_recorder case final recorder?
                    when isConnected || recorder.recording)
                  _recordButton(),
                IconButton(
                  // Distinct from the per-channel "tune" controls: this
                  // configures the meter itself (rate, SD card, device).
                  icon: const Icon(Icons.memory),
                  onPressed: _showDeviceSettings,
                  tooltip: 'Meter settings',
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: _handleMenu,
                  // Grouped: chart view, then files, then app and link.
                  itemBuilder: (_) => [
                    if (isConnected) ...[
                      _menuItem(
                        'maximize-chart',
                        Icons.open_in_full,
                        _chartMaximized ? 'Restore layout' : 'Maximize chart',
                      ),
                      _menuItem(
                        'graph-style',
                        Icons.stacked_line_chart,
                        'Graph style: $_graphStyleLabel',
                      ),
                      _menuItem(
                        'chart-window',
                        Icons.history,
                        'Chart history: '
                            '${formatChartWindow(settings.chartWindow)}',
                      ),
                      _menuItem(
                        'sample-rate',
                        Icons.speed,
                        'Sample rate: ${_sampleRateLabel(provider)}',
                      ),
                      _menuItem('clear-graph', Icons.clear_all, 'Clear chart'),
                      const PopupMenuDivider(),
                    ],
                    _menuItem(
                      'snapshot',
                      Icons.table_view,
                      'Save chart data (CSV)',
                    ),
                    _menuItem('screenshot', Icons.image, 'Save screenshot'),
                    // The standalone logger talks to BlueZ directly.
                    if (Platform.isLinux)
                      _menuItem(
                        'copy-cli',
                        Icons.terminal,
                        'Copy CSV logger command',
                      ),
                    const PopupMenuDivider(),
                    _menuItem('settings', Icons.settings, 'Settings'),
                    _menuItem(
                      'disconnect',
                      Icons.bluetooth_disabled,
                      'Disconnect',
                    ),
                  ],
                ),
              ],
            ),
            body: isConnected
                ? _withConfigPanel(
                    _buildReadingsTab(
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
                    ),
                  )
                : _buildDisconnectedState(provider.state),
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedState(MmConnectionState state) {
    if (_bleProvider.isReconnecting) return _buildReconnectingState();
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

  /// The link dropped and the provider retries with backoff; the history
  /// stays on the chart and sampling resumes on its own.
  Widget _buildReconnectingState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Reconnecting to the meter…',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The Bluetooth link dropped. Attempt '
              '${_bleProvider.reconnectAttempt + 1}; keep the meter on and '
              'in range. Your settings are restored when it reconnects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _bleProvider.cancelReconnect,
              child: const Text('Stop reconnecting'),
            ),
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
        final readings = ReadingsDisplay(
          ch1Value: ch1Value,
          ch2Value: ch2Value,
          ch1Mode: _mode(0),
          ch2Mode: _mode(1),
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
          ch1Average: _ch1Count == 0 ? null : _ch1Sum / _ch1Count,
          ch2Average: _ch2Count == 0 ? null : _ch2Sum / _ch2Count,
          onCh1MinMaxReset: () => setState(_resetCh1MinMax),
          onCh2MinMaxReset: () => setState(_resetCh2MinMax),
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
          onCh1Configure: () => _openChannelConfig(0),
          onCh2Configure: () => _openChannelConfig(1),
          ch1PossiblyFloating: _isPossiblyFloating(_ch1Points, 0.0001),
          ch2PossiblyFloating: _isPossiblyFloating(_ch2Points, 0.005),
          ch1Units: _mode(0).units,
          ch1Max: _displayFullScale(0),
          ch2Units: _mode(1).units,
          ch2Max: _displayFullScale(1),
          significantDigits: provider.significantDigits,
          ch1RangeLabel: _rangeStatus(provider, 0),
          ch2RangeLabel: _rangeStatus(provider, 1),
          compactLayout: landscapeLayout && constraints.maxHeight < 500,
          stackedLayout: landscapeLayout,
          showFloatingValues: showFloatingReadings,
          hasFreshSample: hasFreshReadings,
          showCh1: _showCh1,
          showCh2: _showCh2,
          onShowChannel: (channel) => setState(() {
            if (channel == 0) {
              _showCh1 = true;
            } else {
              _showCh2 = true;
            }
          }),
        );
        final continuityChannel = _continuityGraph ? _continuityChannel : null;
        final chart = Padding(
          padding: const EdgeInsets.all(12),
          child: RealtimeChart(
            ch1Points: _ch1Points,
            ch2Points: _ch2Points,
            showCh1: _showCh1,
            showCh2: _showCh2,
            onCh1VisibilityChanged: (visible) =>
                setState(() => _showCh1 = visible),
            onCh2VisibilityChanged: (visible) =>
                setState(() => _showCh2 = visible),
            ch1Label: _chartLabel(0, continuity: continuityChannel == 0),
            ch2Label: _chartLabel(1, continuity: continuityChannel == 1),
            ch1Continuity: continuityChannel == 0,
            ch2Continuity: continuityChannel == 1,
            timeOrigin: _graphStartTimestamp,
            style: _graphStyle,
          ),
        );
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                // The divider between readings and chart can be dragged;
                // the split is saved as a preference.
                child: ResizableSplit(
                  key: ValueKey(
                    landscapeLayout
                        ? 'landscape-meter-layout'
                        : 'portrait-meter-layout',
                  ),
                  axis: landscapeLayout ? Axis.horizontal : Axis.vertical,
                  fraction: _settingsProvider.readingsFraction,
                  minFraction: SettingsProvider.minReadingsFraction,
                  maxFraction: SettingsProvider.maxReadingsFraction,
                  defaultFraction: SettingsProvider.defaultReadingsFraction,
                  onChanged: (fraction) =>
                      _settingsProvider.readingsFraction = fraction,
                  first: readings,
                  second: chart,
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
            if (_recorder case final recorder? when recorder.recording)
              _footerPill(
                icon: Icons.fiber_manual_record,
                label:
                    'REC ${_elapsed(recorder.startedAt!)} · '
                    '${recorder.rows} rows',
                colors: colors,
                iconColor: Colors.red,
              ),
            _footerPill(
              icon: Icons.data_usage,
              label: '${_bleProvider.sampleRateHz} Hz · $_pointCount samples',
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
    Color? iconColor,
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
          Icon(icon, size: 12, color: iconColor ?? colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Width from which channel configuration docks beside the meter instead
  /// of opening as a full-screen page.
  static const _dockedConfigMinWidth = 900.0;
  static const _configPanelWidth = 380.0;

  /// Opens [channel]'s configuration. On wide windows it docks as a
  /// non-modal side panel, so the readings and chart stay visible and live
  /// while settings change; tapping the same channel again closes it. On
  /// phones it opens as a full-screen page.
  void _openChannelConfig(int channel) {
    if (MediaQuery.sizeOf(context).width >= _dockedConfigMinWidth) {
      setState(
        () => _configChannel = _configChannel == channel ? null : channel,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => ListenableBuilder(
          // Mode, range and offset live in the provider; display options
          // in settings. Both notify, so the page stays current.
          listenable: Listenable.merge([_bleProvider, _settingsProvider]),
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text('CH${channel + 1} configuration')),
            body: SafeArea(child: _channelConfig(channel)),
          ),
        ),
      ),
    );
  }

  /// Places the docked configuration panel beside [main] when it is open.
  Widget _withConfigPanel(Widget main) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final channel = _configChannel;
        if (channel == null || constraints.maxWidth < _dockedConfigMinWidth) {
          return main;
        }
        void close() => setState(() => _configChannel = null);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            const VerticalDivider(width: 1),
            SizedBox(
              width: _configPanelWidth,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): close,
                },
                child: Focus(
                  autofocus: true,
                  child: Material(
                    key: const ValueKey('channel-config-panel'),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: _channelConfig(channel, onClose: close),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// What a channel can measure, grouped like a meter's dial: one tile per
  /// quantity, with DC/AC as a separate choice where it applies.
  List<_Quantity> _quantitiesFor(int channel) => [
    if (channel == 0)
      const _Quantity(
        symbol: 'A',
        label: 'Current',
        hint: 'A jack, up to 10 A',
        dc: ChannelMode.current,
        ac: ChannelMode.currentAc,
      )
    else
      const _Quantity(
        symbol: 'V',
        label: 'Voltage',
        hint: 'V jack, up to 600 V',
        dc: ChannelMode.voltage,
        ac: ChannelMode.voltageAc,
      ),
    const _Quantity(
      symbol: 'mV',
      label: 'Aux voltage',
      hint: 'Shared input, up to 1.2 V',
      dc: ChannelMode.auxiliaryVoltageDc,
      ac: ChannelMode.auxiliaryVoltageAc,
    ),
    const _Quantity(
      symbol: 'Ω',
      label: 'Resistance',
      hint: 'Shared input, 1 kΩ to 10 MΩ',
      dc: ChannelMode.resistance,
    ),
    const _Quantity(
      symbol: '▷|',
      label: 'Diode',
      hint: 'Shared input, forward voltage up to 1.2 V',
      dc: ChannelMode.diode,
    ),
    const _Quantity(
      symbol: '°',
      label: 'Temperature',
      hint: 'Temperature inside the meter',
      dc: ChannelMode.internalTemperature,
    ),
  ];

  Widget _channelConfig(int channel, {VoidCallback? onClose}) {
    final provider = _bleProvider;
    final theme = Theme.of(context);
    final color = channel == 0 ? Colors.red : Colors.blue;
    final mode = _mode(channel);
    final otherName = 'CH${2 - channel}';
    final quantities = _quantitiesFor(channel);
    final selected = quantities.firstWhere(
      (q) => q.dc == mode || q.ac == mode,
      orElse: () => quantities.first,
    );
    final sharedBlocked = quantities.any(
      (q) => !provider.canUseInput(channel, q.dc.input),
    );

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    return ListView(
      key: ValueKey('channel-config-$channel'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (onClose != null)
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CH${channel + 1} configuration',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close (Esc)',
                onPressed: onClose,
              ),
            ],
          ),
        // Live feedback: the value updates while mode, range and zero
        // change.
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.label,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _liveReading(provider, channel),
                  key: ValueKey('sheet-live-reading-$channel'),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: color,
                  ),
                ),
              ),
              if (_rangeStatus(provider, channel) case final range?)
                Text(range, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        section('Measure', [
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final tileWidth = (constraints.maxWidth - 2 * spacing) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final quantity in quantities)
                    SizedBox(
                      width: tileWidth,
                      child: _QuantityTile(
                        quantity: quantity,
                        selected: identical(quantity, selected),
                        color: color,
                        disabledReason:
                            provider.canUseInput(channel, quantity.dc.input)
                            ? null
                            : 'The shared input is in use by $otherName',
                        onTap: () => unawaited(
                          _setChannelMode(
                            channel,
                            // Keep AC when moving between AC-capable inputs.
                            mode.input.isRms && quantity.ac != null
                                ? quantity.ac!
                                : quantity.dc,
                            provider,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(selected.hint, style: theme.textTheme.bodySmall),
          if (selected.ac case final ac?) ...[
            const SizedBox(height: 12),
            SegmentedButton<ChannelMode>(
              segments: [
                ButtonSegment(value: selected.dc, label: const Text('DC')),
                ButtonSegment(value: ac, label: const Text('AC (RMS)')),
              ],
              selected: {mode},
              onSelectionChanged: (choice) =>
                  unawaited(_setChannelMode(channel, choice.single, provider)),
            ),
          ],
          if (sharedBlocked) ...[
            const SizedBox(height: 8),
            Text(
              'Aux voltage, resistance and diode share one input, which '
              '$otherName is using.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ]),
        section('Range', [
          _rangeSelector(channel, provider, (change) => setState(change)),
        ]),
        section('Zero', [_zeroControl(channel, provider)]),
        if (mode.hasTone)
          section(mode == ChannelMode.diode ? 'Tone' : 'Continuity', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _continuityToneEnabled ? Icons.volume_up : Icons.volume_off,
              ),
              title: Text(
                mode == ChannelMode.diode ? 'Short tone' : 'Continuity tone',
              ),
              subtitle: Text(
                mode == ChannelMode.diode
                    ? 'Beep below ${diodeShortVolts.toStringAsFixed(1)} V, '
                          'which means a shorted diode.'
                    : 'Beep below ${continuityThresholdOhms.round()} Ω. '
                          'Holds the 1 kΩ range so the beep follows the '
                          'probes.',
              ),
              value: _continuityToneEnabled,
              onChanged: (enabled) {
                setState(() => _setContinuityToneEnabled(enabled));
                if (mode == ChannelMode.resistance) {
                  unawaited(provider.setRange(channel, enabled ? 0 : null));
                }
              },
            ),
            if (mode == ChannelMode.resistance)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.show_chart),
                title: const Text('Continuity graph'),
                subtitle: const Text('Plot open or continuous instead of ohms'),
                value: _continuityGraph,
                onChanged: (enabled) =>
                    setState(() => _continuityGraph = enabled),
              ),
          ]),
        section('Display', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show channel'),
            subtitle: const Text('In the readings and the chart'),
            value: channel == 0 ? _showCh1 : _showCh2,
            onChanged: (visible) => setState(() {
              if (channel == 0) {
                _showCh1 = visible;
              } else {
                _showCh2 = visible;
              }
            }),
          ),
          const SizedBox(height: 4),
          Text('Units', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          SegmentedButton<DisplayUnit>(
            showSelectedIcon: false,
            segments: [
              for (final unit in DisplayUnit.choicesFor(mode.units))
                ButtonSegment(value: unit, label: Text(unit.label(mode.units))),
            ],
            selected: {
              DisplayUnit.choicesFor(
                    mode.units,
                  ).contains(channel == 0 ? _ch1DisplayUnit : _ch2DisplayUnit)
                  ? (channel == 0 ? _ch1DisplayUnit : _ch2DisplayUnit)
                  : DisplayUnit.auto,
            },
            onSelectionChanged: (choice) => setState(() {
              if (channel == 0) {
                _ch1DisplayUnit = choice.single;
              } else {
                _ch2DisplayUnit = choice.single;
              }
            }),
          ),
        ]),
      ],
    );
  }

  Widget _rangeSelector(
    int channel,
    BleProvider provider,
    void Function(VoidCallback) update,
  ) {
    final ranges = provider.ranges(channel);
    final mode = _mode(channel);
    final textTheme = Theme.of(context).textTheme;
    if (ranges.isEmpty) {
      return Text('Connect to read the ranges', style: textTheme.bodySmall);
    }
    if (ranges.length == 1) {
      return Text(
        'Fixed range: ${_rangeLabel(ranges.single, mode)}',
        style: textTheme.bodySmall,
      );
    }
    final auto = provider.autoRange(channel);
    final active =
        ranges[provider.rangeIndex(channel).clamp(0, ranges.length - 1)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(auto ? 'Auto · ${_rangeLabel(active, mode)}' : 'Auto'),
          selected: auto,
          onSelected: (selected) {
            if (selected) unawaited(provider.setRange(channel, null));
          },
        ),
        for (var i = 0; i < ranges.length; i++)
          ChoiceChip(
            label: Text(_rangeLabel(ranges[i], mode)),
            selected: !auto && provider.rangeIndex(channel) == i,
            onSelected: (selected) {
              if (selected) unawaited(provider.setRange(channel, i));
            },
          ),
      ],
    );
  }

  Widget _zeroControl(int channel, BleProvider provider) {
    final mode = _mode(channel);
    final offset = provider.offset(channel);
    final readings = provider.hasFreshReadings ? provider.latestReadings : null;
    final canZero = readings != null && !readings.overload(channel);
    final format = ReadingFormat(
      units: mode.units,
      fullScale: _displayFullScale(channel),
      significantDigits: provider.significantDigits,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Relative reading'),
      subtitle: Text(
        offset == 0
            ? mode == ChannelMode.resistance
                  ? 'Short the probes and zero to remove lead resistance.'
                  : 'Subtract the present reading from later readings.'
            : 'Subtracting ${format.format(offset)}',
      ),
      trailing: offset == 0
          ? FilledButton.tonal(
              onPressed: canZero
                  ? () => unawaited(
                      provider.setOffset(channel, readings.value(channel)),
                    )
                  : null,
              child: const Text('Zero'),
            )
          : OutlinedButton(
              onPressed: () => unawaited(provider.setOffset(channel, 0)),
              child: const Text('Clear'),
            ),
    );
  }

  /// The present reading of [channel], formatted for the config sheet.
  String _liveReading(BleProvider provider, int channel) {
    final readings = provider.hasFreshReadings ? provider.latestReadings : null;
    if (readings == null) return '—';
    final value = _displayValue(readings, channel);
    if (value.isNaN) return 'OL';
    return ReadingFormat(
      units: _mode(channel).units,
      fullScale: _displayFullScale(channel),
      significantDigits: provider.significantDigits,
      displayUnit: channel == 0 ? _ch1DisplayUnit : _ch2DisplayUnit,
    ).format(value);
  }

  /// "Auto · 60 V" or "600 V" for the reading card.
  String? _rangeStatus(BleProvider provider, int channel) {
    final fullScale = provider.rangeMax(channel);
    if (fullScale == null) return null;
    final label = _rangeLabel(fullScale, _mode(channel));
    return provider.autoRange(channel) && provider.ranges(channel).length > 1
        ? 'Auto · $label'
        : label;
  }

  String _rangeLabel(double fullScale, ChannelMode mode) {
    final display = mode.toDisplay(fullScale);
    if (mode == ChannelMode.internalTemperature) {
      return '${display.round()} ${mode.units}';
    }
    // Names a range like a meter's dial: "1 kΩ", "1 MΩ".
    final scale = SiScale.forValue(display);
    final value = display * scale.multiplier;
    final text = value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
    return '$text ${scale.prefix}${mode.units}';
  }

  Future<void> _setChannelMode(
    int channel,
    ChannelMode mode,
    BleProvider provider,
  ) async {
    final previous = _mode(channel);
    if (previous == mode) return;
    if (_toneChannel == channel) {
      setState(() => _setContinuityToneEnabled(false));
    }
    final ok = await provider.setInput(channel, mode.input);
    if (!mounted) return;
    if (!ok) {
      _showMessage('The shared input is in use by the other channel');
      return;
    }
    _settingsProvider.setChannelMode(channel, mode);
    setState(() {
      // A fixed prefix chosen for the old quantity (for example mA) is
      // meaningless for the new one (mΩ), so fall back to auto-ranging.
      if (previous.units != mode.units) {
        if (channel == 0) {
          _ch1DisplayUnit = DisplayUnit.auto;
        } else {
          _ch2DisplayUnit = DisplayUnit.auto;
        }
      }
      // Earlier samples were a different quantity; keep the other channel's
      // history and leave a gap in this one.
      final points = channel == 0 ? _ch1Points : _ch2Points;
      for (var i = 0; i < points.length; i++) {
        points[i] = LinePoint(points[i].x, double.nan);
      }
      if (channel == 0) {
        _resetCh1MinMax();
      } else {
        _resetCh2MinMax();
      }
    });
  }

  ChannelMode _mode(int channel) => _bleProvider.mode(channel);

  /// The channel measuring resistance, if any (only one channel can use the
  /// shared input).
  int? get _continuityChannel {
    for (final channel in const [0, 1]) {
      if (_mode(channel) == ChannelMode.resistance) return channel;
    }
    return null;
  }

  /// The channel whose tone is available: resistance or diode, both on the
  /// shared input, so at most one channel.
  int? get _toneChannel {
    for (final channel in const [0, 1]) {
      if (_mode(channel).hasTone) return channel;
    }
    return null;
  }

  double? _displayFullScale(int channel) =>
      _bleProvider.displayFullScale(channel);

  double _displayValue(DeviceReadings readings, int channel) =>
      _bleProvider.displayValue(readings, channel);

  String _chartLabel(int channel, {required bool continuity}) {
    final name = 'CH${channel + 1}';
    if (continuity) {
      return '$name · Continuity (< ${continuityThresholdOhms.round()} Ω)';
    }
    final mode = _mode(channel);
    return '$name · ${mode.label} (${mode.units})';
  }

  String _csvHeader(int channel) {
    final mode = _mode(channel);
    return 'CH${channel + 1} ${mode.label} (${mode.units})';
  }

  String _sampleRateLabel(BleProvider provider) =>
      provider.sampleRateSetting == null
      ? 'Auto (${provider.sampleRateHz} Hz)'
      : '${provider.sampleRateHz} Hz';

  String get _graphStyleLabel => switch (_graphStyle) {
    GraphStyle.split => 'Split',
    GraphStyle.dualAxis => 'Dual axis',
    GraphStyle.sharedAxis => 'Shared',
  };

  void _onBleProviderChanged() {
    if (!mounted) return;
    // Decide on the tone for every sample, ahead of the throttled graph
    // capture, so the beep starts with the reading rather than after it.
    _updateContinuityTone();
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
    final ch1 = _displayValue(reading, 0);
    final ch2 = _displayValue(reading, 1);
    setState(() {
      _ch1Points.add(LinePoint(elapsed, ch1));
      _ch2Points.add(LinePoint(elapsed, ch2));
      if (_ch1MinMaxTracking && !ch1.isNaN) {
        _ch1Sum += ch1;
        _ch1Count++;
        _ch1Minimum = math.min(_ch1Minimum ?? ch1, ch1);
        _ch1Maximum = math.max(_ch1Maximum ?? ch1, ch1);
      }
      if (_ch2MinMaxTracking && !ch2.isNaN) {
        _ch2Sum += ch2;
        _ch2Count++;
        _ch2Minimum = math.min(_ch2Minimum ?? ch2, ch2);
        _ch2Maximum = math.max(_ch2Maximum ?? ch2, ch2);
      }
      _pointCount++;
      // Keep the configured time window; the chart thins long histories.
      final cutoff =
          elapsed - _settingsProvider.chartWindow.inMilliseconds / 1000;
      var expired = 0;
      while (expired < _ch1Points.length && _ch1Points[expired].x < cutoff) {
        expired++;
      }
      if (expired > 0) {
        _ch1Points.removeRange(0, expired);
        _ch2Points.removeRange(0, expired);
      }
    });
  }

  void _updateContinuityTone() {
    final reading = _bleProvider.hasFreshReadings
        ? _bleProvider.latestReadings
        : null;
    final continuityReady =
        _continuityReadyAt != null &&
        !DateTime.now().isBefore(_continuityReadyAt!);
    final channel = _toneChannel;
    final shouldSound =
        reading != null &&
        channel != null &&
        _bleProvider.state == MmConnectionState.connected &&
        _continuityToneEnabled &&
        continuityReady &&
        _mode(channel).beepsAt(_displayValue(reading, channel));
    if (shouldSound == _continuityToneWanted) return;
    _continuityToneWanted = shouldSound;
    if (shouldSound) {
      unawaited(_startContinuityTone());
    } else {
      _stopContinuityTone();
    }
  }

  Future<String> _continuityToneFile() async =>
      _continuityTonePath ??= await _writeContinuityTone();

  Future<void> _startContinuityTone() async {
    if (!_continuityToneWanted) return;
    try {
      await _continuityTone.start(toneFile: _continuityToneFile);
    } catch (error) {
      _devLog('continuity tone failed: $error');
    }
  }

  void _stopContinuityTone() {
    _continuityTone.stop();
  }

  /// Arms or releases the audio output together with the tone setting.
  void _setContinuityToneEnabled(bool enabled) {
    _continuityToneEnabled = enabled;
    _settingsProvider.continuityTone = enabled;
    _continuityReadyAt = enabled
        ? DateTime.now().add(const Duration(milliseconds: 300))
        : null;
    _continuityToneWanted = false;
    if (enabled) {
      unawaited(_continuityTone.prepare(toneFile: _continuityToneFile));
    } else {
      _continuityTone.release();
    }
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
    _ch1Sum = 0;
    _ch1Count = 0;
  }

  void _resetCh2MinMax() {
    _ch2Minimum = null;
    _ch2Maximum = null;
    _ch2Sum = 0;
    _ch2Count = 0;
  }

  /// Where snapshots and screenshots go: the Downloads folder on desktop,
  /// where people look for saved files, and app documents elsewhere.
  Future<Directory> _recordsDirectory() async {
    Directory? base;
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      try {
        base = await getDownloadsDirectory();
      } catch (_) {
        base = null;
      }
    }
    base ??= await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/MooshRevolt');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  void _showSaved(File file) {
    if (!mounted) return;
    final canReveal = Platform.isMacOS || Platform.isLinux;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${file.uri.pathSegments.last}'),
        action: canReveal
            ? SnackBarAction(
                label: 'Show',
                onPressed: () => unawaited(_reveal(file)),
              )
            : null,
      ),
    );
  }

  static Future<void> _reveal(File file) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
      }
    } catch (_) {
      // Revealing is a convenience; the file is saved either way.
    }
  }

  String _timestampName() =>
      DateTime.now().toIso8601String().replaceAll(':', '-');

  Future<void> _saveDataSnapshot() async {
    final rows = <String>[
      'elapsed_s,${_csvHeader(0)},${_csvHeader(1)}',
      for (var i = 0; i < _ch1Points.length; i++)
        '${_ch1Points[i].x},${_csvValue(_ch1Points[i].y)},'
            '${_csvValue(_ch2Points[i].y)}',
    ];
    await _saveRows(rows, 'snapshot');
  }

  /// Overloaded samples are stored as NaN and exported as "OL".
  static String _csvValue(double value) => value.isNaN ? 'OL' : '$value';

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
    _showSaved(file);
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
    _showSaved(file);
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
              runSpacing: 8,
              children: [null, ...provider.sampleRates].map((rate) {
                return ChoiceChip(
                  label: Text(rate == null ? 'Auto' : '$rate Hz'),
                  selected: provider.sampleRateSetting == rate,
                  onSelected: (selected) {
                    if (selected) unawaited(_setSampleRate(rate));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Auto samples DC at 125 Hz for the most digits and AC at '
              '4 kHz so RMS covers whole mains cycles.',
              style: Theme.of(context).textTheme.bodySmall,
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

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(label)),
          ],
        ),
      );

  /// The app-wide CSV recorder; absent in tests that do not provide it.
  /// Build methods watch it, so the REC indicator updates with each row.
  CsvRecorder? get _recorder => context.watch<CsvRecorder?>();

  /// The recorder for event handlers, which must not subscribe.
  CsvRecorder? get _recorderForAction => context.read<CsvRecorder?>();

  Widget _recordButton() {
    final recording = _recorder?.recording ?? false;
    return IconButton(
      key: const ValueKey('record-button'),
      tooltip: recording ? 'Stop recording' : 'Record every reading to CSV',
      icon: Icon(
        recording ? Icons.stop_circle : Icons.fiber_manual_record,
        color: Colors.red,
      ),
      onPressed: _toggleRecording,
    );
  }

  Future<void> _toggleRecording() async {
    final recorder = _recorderForAction;
    if (recorder == null) return;
    if (recorder.recording) {
      final file = await recorder.stop();
      if (file != null) _showSaved(file);
    } else {
      await recorder.start(await _recordsDirectory());
      _showMessage('Recording every reading to CSV');
    }
  }

  static String _elapsed(DateTime start) {
    final d = DateTime.now().difference(start);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  bool get _chartMaximized =>
      _settingsProvider.readingsFraction <=
      SettingsProvider.minReadingsFraction;

  void _handleMenu(String value) {
    switch (value) {
      case 'maximize-chart':
        _settingsProvider.readingsFraction = _chartMaximized
            ? SettingsProvider.defaultReadingsFraction
            : SettingsProvider.minReadingsFraction;
        break;
      case 'settings':
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
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
      case 'chart-window':
        unawaited(_showChartWindowPicker());
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

  Future<void> _showChartWindowPicker() async {
    final current = _settingsProvider.chartWindow;
    final window = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chart history'),
        children: SettingsProvider.chartWindows
            .map(
              (window) => ListTile(
                leading: Icon(
                  window == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(formatChartWindow(window)),
                onTap: () => Navigator.pop(context, window),
              ),
            )
            .toList(),
      ),
    );
    if (window != null && mounted) _settingsProvider.chartWindow = window;
  }

  Future<void> _showSampleRatePicker() async {
    final current = _bleProvider.sampleRateSetting;
    // Wrap the choice so "Auto" (null) differs from a dismissed dialog.
    final choice = await showDialog<({int? rate})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sample rate'),
        children: [null, ..._bleProvider.sampleRates]
            .map(
              (rate) => ListTile(
                leading: Icon(
                  rate == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(
                  rate == null ? 'Auto (125 Hz DC, 4 kHz AC)' : '$rate Hz',
                ),
                onTap: () => Navigator.pop(context, (rate: rate)),
              ),
            )
            .toList(),
      ),
    );
    if (choice == null || !mounted) return;
    await _setSampleRate(choice.rate);
  }

  Future<void> _setSampleRate(int? rate) async {
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
        '--channel $channel --rate ${_bleProvider.sampleRateHz} '
        '--output readings.csv';
    await Clipboard.setData(ClipboardData(text: command));
    _showMessage('CSV logger command copied');
  }
}

/// A measurable quantity: its DC mode and, where the meter supports it, the
/// AC (RMS) variant.
class _Quantity {
  const _Quantity({
    required this.symbol,
    required this.label,
    required this.hint,
    required this.dc,
    this.ac,
  });

  final String symbol;
  final String label;
  final String hint;
  final ChannelMode dc;
  final ChannelMode? ac;
}

/// A dial-style tile: the quantity's symbol large, its name below.
class _QuantityTile extends StatelessWidget {
  const _QuantityTile({
    required this.quantity,
    required this.selected,
    required this.color,
    required this.onTap,
    this.disabledReason,
  });

  final _Quantity quantity;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = disabledReason == null;
    final tile = Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: quantity.label,
      child: Material(
        color: selected ? color.withAlpha(30) : colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('quantity-${quantity.label}'),
          borderRadius: BorderRadius.circular(12),
          onTap: enabled && !selected ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    quantity.symbol,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    quantity.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: disabledReason ?? quantity.hint, child: tile);
  }
}
