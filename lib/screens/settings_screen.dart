import 'package:moosh_revolt/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moosh_revolt/models/meter_reading.dart';
import 'package:moosh_revolt/services/prometheus_exporter.dart';
import 'package:moosh_revolt/services/settings_service.dart';
import 'package:moosh_revolt/screens/about_screen.dart';

/// App settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // --- Connection ---
              Text(
                context.l10n.connection,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              SwitchListTile(
                title: Text(context.l10n.autoConnect),
                subtitle: Text(context.l10n.autoConnectHelp),
                value: settings.autoConnect,
                onChanged: (v) => settings.autoConnect = v,
              ),
              SwitchListTile(
                title: Text('Reconnect automatically'),
                subtitle: Text(
                  'Re-establish the link when the meter drops out of range',
                ),
                value: settings.autoReconnect,
                onChanged: (v) => settings.autoReconnect = v,
              ),

              Divider(height: 32),

              ListTile(
                title: Text(context.l10n.language),
                trailing: DropdownButton<String?>(
                  value: settings.locale?.languageCode,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.l10n.systemLanguage),
                    ),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                    const DropdownMenuItem(
                      value: 'fr',
                      child: Text('Français'),
                    ),
                  ],
                  onChanged: (value) => settings.languageCode = value,
                ),
              ),
              // --- Appearance ---
              Text(
                context.l10n.appearance,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              ListTile(
                title: Text('Theme'),
                subtitle: Text('System follows your OS appearance'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: [
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
              ListTile(
                title: Text('Temperature'),
                subtitle: Text('Unit for the meter\'s internal temperature'),
                trailing: SegmentedButton<TemperatureUnit>(
                  segments: [
                    for (final unit in TemperatureUnit.values)
                      ButtonSegment(value: unit, label: Text(unit.symbol)),
                  ],
                  selected: {settings.temperatureUnit},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      settings.temperatureUnit = selection.single,
                ),
              ),
              SwitchListTile(
                title: Text(context.l10n.showFloating),
                subtitle: Text(context.l10n.showFloatingHelp),
                value: settings.showFloatingReadings,
                onChanged: (value) => settings.showFloatingReadings = value,
              ),

              Divider(height: 32),

              // --- Remembered Devices ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.rememberedDevices,
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
              SizedBox(height: 8),
              if (settings.rememberedDevices.isEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 16),
                  child: Text(
                    'No devices remembered yet. Connect to a device and tap context.l10n.remember to save it.',
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
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(context.l10n.forgetQuestion),
                              content: Text(
                                'Remove "${dev.name}" from remembered devices?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(context.l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(context.l10n.forget),
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
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.bluetooth),
                        title: Text(
                          dev.name.isNotEmpty
                              ? dev.name
                              : context.l10n.unknownDevice,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.address,
                              style: TextStyle(
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
                              Icon(
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

              Divider(height: 32),

              // --- Data Collection ---
              Text(
                context.l10n.dataCollection,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              ListTile(
                title: Text(context.l10n.defaultSampleRate),
                subtitle: Text('Auto uses 125 Hz for DC and 4 kHz for AC'),
                // 0 stands for Auto in the menu; the setting stores null.
                trailing: DropdownButton<int>(
                  value: settings.sampleRate ?? 0,
                  underline: SizedBox.shrink(),
                  onChanged: (rate) =>
                      settings.sampleRate = rate == 0 ? null : rate,
                  items: [0, 125, 250, 500, 1000, 2000, 4000, 8000]
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r == 0 ? context.l10n.auto : '$r Hz'),
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                title: Text('Chart history'),
                subtitle: Text('How much time the live chart keeps'),
                trailing: DropdownButton<Duration>(
                  value:
                      SettingsProvider.chartWindows.contains(
                        settings.chartWindow,
                      )
                      ? settings.chartWindow
                      : null,
                  underline: SizedBox.shrink(),
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
              Divider(height: 32),

              // --- Integrations ---
              Text(
                'Integrations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              const _PrometheusSettings(),
              Divider(height: 32),

              // --- About ---
              Text(
                context.l10n.about,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('MooshRevolt'),
                subtitle: Text('Version 1.0.0'),
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => AboutScreen())),
              ),
              ListTile(
                title: Text('BLE service UUID'),
                subtitle: Text(_serviceUuid),
                trailing: Icon(Icons.copy, size: 16),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _serviceUuid));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Service UUID copied')),
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
          title: Text('Prometheus exporter'),
          subtitle: Text(status),
          value: settings.exporterEnabled,
          onChanged: (enabled) => settings.exporterEnabled = enabled,
        ),
        if (settings.exporterEnabled) ...[
          ListTile(
            title: Text('Port'),
            trailing: SizedBox(
              width: 96,
              child: TextFormField(
                key: ValueKey('exporter-port-${settings.exporterPort}'),
                initialValue: '${settings.exporterPort}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(isDense: true),
                onFieldSubmitted: (text) {
                  final port = int.tryParse(text);
                  if (port != null) settings.exporterPort = port;
                },
              ),
            ),
          ),
          SwitchListTile(
            title: Text('Allow access from other devices'),
            subtitle: Text(
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
