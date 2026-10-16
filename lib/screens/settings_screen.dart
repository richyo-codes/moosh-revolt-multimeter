import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moosh_revolt/services/prometheus_exporter.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/screens/about_screen.dart';

/// App settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Connection ---
              const Text(
                'Connection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Auto-connect on launch'),
                subtitle: const Text(
                  'Automatically reconnect to last remembered device',
                ),
                value: settings.autoConnect,
                onChanged: (v) => settings.autoConnect = v,
              ),

              const Divider(height: 32),

              // --- Appearance ---
              const Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Theme'),
                subtitle: const Text('System follows your OS appearance'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      tooltip: 'System',
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      tooltip: 'Light',
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      tooltip: 'Dark',
                    ),
                  ],
                  selected: {settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      settings.themeMode = selection.single,
                ),
              ),
              SwitchListTile(
                title: const Text('Show values for floating probes'),
                subtitle: const Text(
                  'Keep displaying near-zero readings when a probe may be unconnected',
                ),
                value: settings.showFloatingReadings,
                onChanged: (value) => settings.showFloatingReadings = value,
              ),

              const Divider(height: 32),

              // --- Remembered Devices ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Remembered Devices',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Chip(
                    label: Text('${settings.rememberedDeviceCount}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (settings.rememberedDevices.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 16),
                  child: Text(
                    'No devices remembered yet. Connect to a device and tap "Remember" to save it.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...settings.rememberedDevices.map((dev) {
                  return Dismissible(
                    key: Key(dev.address),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red.shade300,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Forget device?'),
                              content: Text(
                                'Remove "${dev.name}" from remembered devices?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Forget'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) async {
                      await settings.unrememberDevice(dev.address);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${dev.name} forgotten')),
                        );
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(
                          dev.name.isNotEmpty ? dev.name : 'Unknown Device',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.address,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Remembered: ${dev.rememberedAt.toLocaleStringShort()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (dev.autoConnect)
                              const Icon(
                                Icons.flash_on,
                                color: Colors.amber,
                                size: 18,
                              ),
                            Switch(
                              value: dev.autoConnect,
                              onChanged: (_) async {
                                await settings.toggleDeviceAutoConnect(
                                  dev.address,
                                );
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const Divider(height: 32),

              // --- Data Collection ---
              const Text(
                'Data Collection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Default sample rate'),
                subtitle: const Text(
                  'Auto uses 125 Hz for DC and 4 kHz for AC',
                ),
                // 0 stands for Auto in the menu; the setting stores null.
                trailing: DropdownButton<int>(
                  value: settings.sampleRate ?? 0,
                  underline: const SizedBox.shrink(),
                  onChanged: (rate) =>
                      settings.sampleRate = rate == 0 ? null : rate,
                  items: [0, 125, 250, 500, 1000, 2000, 4000, 8000]
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r == 0 ? 'Auto' : '$r Hz'),
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                title: const Text('Chart history'),
                subtitle: const Text('How much time the live chart keeps'),
                trailing: DropdownButton<Duration>(
                  value:
                      SettingsProvider.chartWindows.contains(
                        settings.chartWindow,
                      )
                      ? settings.chartWindow
                      : null,
                  underline: const SizedBox.shrink(),
                  onChanged: (window) {
                    if (window != null) settings.chartWindow = window;
                  },
                  items: SettingsProvider.chartWindows
                      .map(
                        (w) => DropdownMenuItem(
                          value: w,
                          child: Text(formatChartWindow(w)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 32),

              // --- Integrations ---
              const Text(
                'Integrations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const _PrometheusSettings(),
              const Divider(height: 32),

              // --- About ---
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('MooshRevolt'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
              ListTile(
                title: const Text('BLE service UUID'),
                subtitle: const Text(_serviceUuid),
                trailing: const Icon(Icons.copy, size: 16),
                onTap: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _serviceUuid),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service UUID copied')),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Short date formatter.
extension on DateTime {
  String toLocaleStringShort() {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, ${year.toString().substring(2)} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

const _serviceUuid = '1BC5FFA0-0200-62AB-E411-F254E005DBD4';

/// Prometheus exporter controls with the live endpoint status.
class _PrometheusSettings extends StatelessWidget {
  const _PrometheusSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // The exporter is absent in widget tests that only provide settings.
    final exporter = context.watch<PrometheusExporter?>();
    final status = !settings.exporterEnabled
        ? 'Serve live readings at /metrics for Prometheus or Grafana'
        : exporter?.error ??
              (exporter?.url != null
                  ? 'Serving ${exporter!.url}'
                  : 'Starting…');
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Prometheus exporter'),
          subtitle: Text(status),
          value: settings.exporterEnabled,
          onChanged: (enabled) => settings.exporterEnabled = enabled,
        ),
        if (settings.exporterEnabled) ...[
          ListTile(
            title: const Text('Port'),
            trailing: SizedBox(
              width: 96,
              child: TextFormField(
                key: ValueKey('exporter-port-${settings.exporterPort}'),
                initialValue: '${settings.exporterPort}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(isDense: true),
                onFieldSubmitted: (text) {
                  final port = int.tryParse(text);
                  if (port != null) settings.exporterPort = port;
                },
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Allow access from other devices'),
            subtitle: const Text(
              'Anyone on your network can read the measurements. Off '
              'serves this computer only.',
            ),
            value: settings.exporterAllowRemote,
            onChanged: (allow) => settings.exporterAllowRemote = allow,
          ),
        ],
      ],
    );
  }
}
