import 'package:flutter/material.dart';
import 'package:moosh_revolt/widgets/mooshrevolt_mark.dart';

/// Project information and licensing details.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About MooshRevolt')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: MooshRevoltMark(size: 128)),
              const SizedBox(height: 20),
              Text(
                'MooshRevolt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'A modern Mooshimeter client',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'MooshRevolt is an Android and Linux desktop app for the '
                'Mooshimeter BLE multimeter. It provides live readings, '
                'graphing, logging, and a practical interface for modern devices.',
              ),
              const SizedBox(height: 24),
              Text(
                'Why it exists',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'The project grew from using a Mooshimeter bought around 2016. '
                'There was no dedicated Linux desktop app, existing libsigrok '
                'support could be unreliable, and the original Android experience '
                'was not designed for current devices. MooshRevolt brings the '
                'meter to a shared Flutter codebase for Linux and Android.',
              ),
              const SizedBox(height: 24),
              Text('License', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Copyright © Rich Young. Licensed under GNU GPL v3.0 or later. '
                'Source code and modified versions must remain available under the same license.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
