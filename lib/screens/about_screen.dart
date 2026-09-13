import 'package:moosh_revolt/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:moosh_revolt/widgets/mooshrevolt_mark.dart';

/// Project information and licensing details.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutApp)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: EdgeInsets.all(24),
            children: [
              Center(child: MooshRevoltMark(size: 128)),
              SizedBox(height: 20),
              Text(
                'MooshRevolt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 32),
              Text(
                context.l10n.modernClient,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Text(context.l10n.appDescription),
              SizedBox(height: 24),
              Text(
                context.l10n.whyExists,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Text(context.l10n.appBackground),
              SizedBox(height: 24),
              Text(
                context.l10n.license,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Text(context.l10n.licenseNotice),
            ],
          ),
        ),
      ),
    );
  }
}
