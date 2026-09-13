import 'package:moosh_revolt/l10n/localization.dart';
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
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              ListTile(
                title: Text(context.l10n.language),
                leading: const Icon(Icons.language),
                trailing: DropdownButton<String>(
                  value: settings.locale?.languageCode ?? 'system',
                  onChanged: (value) =>
                      settings.languageCode = value == 'system' ? null : value,
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(context.l10n.systemLanguage),
                    ),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                    const DropdownMenuItem(
                      value: 'fr',
                      child: Text('Français'),
                    ),
                  ],
                ),
              ),
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
                title: Text(context.l10n.skipFirmware),
                subtitle: Text(context.l10n.skipFirmwareHelp),
                value: settings.skipUpgrade,
                onChanged: (v) => settings.skipUpgrade = v,
              ),

              Divider(height: 32),

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
              SwitchListTile(
                title: Text(context.l10n.darkMode),
                subtitle: Text(context.l10n.darkModeHelp),
                value: settings.themeMode == ThemeMode.dark,
                onChanged: (_) => settings.toggleTheme(),
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
                    context.l10n.noRemembered,
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
                                context.l10n.removeDevice(dev.name),
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
                          SnackBar(
                            content: Text(
                              context.l10n.deviceForgotten(dev.name),
                            ),
                          ),
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
                              context.l10n.rememberedDate(
                                MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(dev.rememberedAt),
                              ),
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
                subtitle: Text('${settings.sampleRate} Hz'),
                trailing: PopupMenuButton<int>(
                  onSelected: (rate) => settings.sampleRate = rate,
                  itemBuilder: (_) => [125, 250, 500, 1000, 2000, 4000, 8000]
                      .map((r) => PopupMenuItem(value: r, child: Text('$r Hz')))
                      .toList(),
                ),
              ),
              ListTile(
                title: Text(context.l10n.maxGraphPoints),
                subtitle: Text('${settings.graphMaxPoints}'),
                trailing: PopupMenuButton<int>(
                  onSelected: (points) => settings.graphMaxPoints = points,
                  itemBuilder: (_) => [100, 300, 500, 1000, 3000]
                      .map((p) => PopupMenuItem(value: p, child: Text('$p')))
                      .toList(),
                ),
              ),
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
                title: Text(context.l10n.serviceUuids),
                subtitle: Text('1BC5FFA0-0200-62AB-E411-F254E005DBD4'),
                trailing: Icon(Icons.copy, size: 16),
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
