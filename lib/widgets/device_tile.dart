import 'package:flutter/material.dart';

/// A list tile showing a discovered Mooshimeter device.
class DeviceTile extends StatelessWidget {
  final String name;
  final String address;
  final int rssi;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  /// Whether this device has been remembered (persisted for auto-connect).
  final bool isRemembered;

  /// Called when the user taps the "Remember" action.
  final VoidCallback? onRemember;

  /// Called when the user taps the "Forget" action.
  final VoidCallback? onForget;

  const DeviceTile({
    super.key,
    required this.name,
    required this.address,
    required this.rssi,
    this.isConnected = false,
    this.isConnecting = false,
    required this.onTap,
    this.isRemembered = false,
    this.onRemember,
    this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final rssiColor = _rssiColor(rssi);

    return ListTile(
      leading: Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rssiColor.withAlpha((0.15 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : isRemembered
                  ? Icons.bluetooth_searching
                  : Icons.bluetooth_searching,
              color: rssiColor,
              size: 28,
            ),
          ),
          // Remembered indicator
          if (isRemembered && !isConnected)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 8, color: Colors.white),
              ),
            ),
          // RSSI badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: rssiColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.signal_cellular_alt,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        name.isNotEmpty ? name : 'Unknown Device',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            '$address • $rssiLabel ($rssi dBm)',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          if (isRemembered)
            Text(
              'Remembered — tap to auto-connect',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700),
            ),
        ],
      ),
      trailing: isConnecting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isConnected
          ? const Chip(
              label: Text('Connected', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            )
          : isRemembered
          ? IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.amber),
              onPressed: onTap,
              tooltip: 'Connect',
            )
          : const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      onLongPress: () {
        // Long press shows remember/forget options
        _showDeviceActions(context);
      },
    );
  }

  void _showDeviceActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRemembered)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Forget device'),
                onTap: () {
                  Navigator.pop(ctx);
                  onForget?.call();
                },
              ),
            if (!isRemembered)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Remember device'),
                subtitle: const Text('Auto-connect next time'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRemember?.call();
                },
              ),
            if (!isRemembered && onRemember == null)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Remember device'),
                subtitle: const Text('Auto-connect next time'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Inline remember if no callback provided
                  // (handled by parent via onRemember)
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get rssiLabel {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }
}
