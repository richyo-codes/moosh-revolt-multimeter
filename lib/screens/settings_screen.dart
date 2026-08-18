import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
              SwitchListTile(
                title: const Text('Skip firmware check'),
                subtitle: const Text('Skip OAD firmware update prompt'),
                value: settings.skipUpgrade,
                onChanged: (v) => settings.skipUpgrade = v,
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
              SwitchListTile(
                title: const Text('Dark mode'),
                subtitle: const Text(
                  'Use a dark color scheme throughout the app',
                ),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (_) => settings.toggleTheme(),
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
                subtitle: Text('${settings.sampleRate} Hz'),
                trailing: PopupMenuButton<int>(
                  onSelected: (rate) => settings.sampleRate = rate,
                  itemBuilder: (_) => [125, 250, 500, 1000, 2000, 4000, 8000]
                      .map((r) => PopupMenuItem(value: r, child: Text('$r Hz')))
                      .toList(),
                ),
              ),
              ListTile(
                title: const Text('Max graph points'),
                subtitle: Text('${settings.graphMaxPoints}'),
                trailing: PopupMenuButton<int>(
                  onSelected: (points) => settings.graphMaxPoints = points,
                  itemBuilder: (_) => [100, 300, 500, 1000, 3000]
                      .map((p) => PopupMenuItem(value: p, child: Text('$p')))
                      .toList(),
                ),
              ),
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
                title: const Text('BLE Service UUIDs'),
                subtitle: const Text('1BC5FFA0-0200-62AB-E411-F254E005DBD4'),
                trailing: const Icon(Icons.copy, size: 16),
                onTap: () {
                  // TODO: Clipboard copy
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
