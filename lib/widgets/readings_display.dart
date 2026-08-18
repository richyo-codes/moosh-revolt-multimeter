import 'package:flutter/material.dart';
import 'package:moosh_revolt/models/meter_reading.dart';

/// Displays the two-channel readings prominently.
class ReadingsDisplay extends StatelessWidget {
  final double ch1Value;
  final double ch2Value;
  final ChannelMode ch1Mode;
  final ChannelMode ch2Mode;
  final bool ch1OutOfRange;
  final bool ch2OutOfRange;
  final DisplayUnit ch1DisplayUnit;
  final DisplayUnit ch2DisplayUnit;
  final ValueChanged<DisplayUnit>? onCh1DisplayUnitChanged;
  final ValueChanged<DisplayUnit>? onCh2DisplayUnitChanged;
  final bool ch1PossiblyFloating;
  final bool ch2PossiblyFloating;
  final String ch1Units;
  final String ch2Units;
  final double ch1Max;
  final double ch2Max;
  final bool compactLayout;
  final bool showFloatingValues;
  final bool hasFreshSample;
  final bool showCh1;
  final bool showCh2;

  const ReadingsDisplay({
    super.key,
    required this.ch1Value,
    required this.ch2Value,
    required this.ch1Mode,
    required this.ch2Mode,
    this.ch1OutOfRange = false,
    this.ch2OutOfRange = false,
    this.ch1DisplayUnit = DisplayUnit.auto,
    this.ch2DisplayUnit = DisplayUnit.auto,
    this.onCh1DisplayUnitChanged,
    this.onCh2DisplayUnitChanged,
    this.ch1PossiblyFloating = false,
    this.ch2PossiblyFloating = false,
    this.ch1Units = 'A',
    this.ch2Units = 'V',
    this.ch1Max = 10,
    this.ch2Max = 600,
    this.compactLayout = false,
    this.showFloatingValues = false,
    this.hasFreshSample = true,
    this.showCh1 = true,
    this.showCh2 = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = false;
    final ch1 = _ChannelReading(
      label: 'CH1 · ${ch1Mode.label}',
      value: ch1Value,
      units: ch1Units,
      max: ch1Max,
      digits: Channel.ch1.digits,
      isOutOfRange: ch1OutOfRange,
      displayUnit: ch1DisplayUnit,
      onDisplayUnitChanged: onCh1DisplayUnitChanged,
      possiblyFloating: ch1PossiblyFloating,
      hasFreshSample: hasFreshSample,
      color: Colors.red,
      compact: isCompact,
      showFloatingValues: showFloatingValues,
    );
    final ch2 = _ChannelReading(
      label: 'CH2 · ${ch2Mode.label}',
      value: ch2Value,
      units: ch2Units,
      max: ch2Max,
      digits: Channel.ch2.digits,
      isOutOfRange: ch2OutOfRange,
      displayUnit: ch2DisplayUnit,
      onDisplayUnitChanged: onCh2DisplayUnitChanged,
      possiblyFloating: ch2PossiblyFloating,
      hasFreshSample: hasFreshSample,
      color: Colors.blue,
      compact: isCompact,
      showFloatingValues: showFloatingValues,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = compactLayout || constraints.maxHeight < 240;
        final compactCh1 = _ChannelReading(
          label: 'CH1 · ${ch1Mode.label}',
          value: ch1Value,
          units: ch1Units,
          max: ch1Max,
          digits: Channel.ch1.digits,
          isOutOfRange: ch1OutOfRange,
          displayUnit: ch1DisplayUnit,
          onDisplayUnitChanged: onCh1DisplayUnitChanged,
          possiblyFloating: ch1PossiblyFloating,
          hasFreshSample: hasFreshSample,
          color: Colors.red,
          compact: compact,
          showFloatingValues: showFloatingValues,
        );
        final compactCh2 = _ChannelReading(
          label: 'CH2 · ${ch2Mode.label}',
          value: ch2Value,
          units: ch2Units,
          max: ch2Max,
          digits: Channel.ch2.digits,
          isOutOfRange: ch2OutOfRange,
          displayUnit: ch2DisplayUnit,
          onDisplayUnitChanged: onCh2DisplayUnitChanged,
          possiblyFloating: ch2PossiblyFloating,
          hasFreshSample: hasFreshSample,
          color: Colors.blue,
          compact: compact,
          showFloatingValues: showFloatingValues,
        );
        if (!showCh1 && !showCh2) {
          return const Center(
            key: ValueKey('channel-readings-none'),
            child: Text('Enable a channel to show its reading'),
          );
        }
        if (!showCh1) {
          return _readingPanel(context, compactCh2);
        }
        if (!showCh2) {
          return _readingPanel(context, compactCh1);
        }
        if (compact) {
          return Row(
            key: const ValueKey('channel-readings-compact'),
            children: [
              Expanded(child: _readingPanel(context, compactCh1)),
              const SizedBox(width: 4),
              Expanded(child: _readingPanel(context, compactCh2)),
            ],
          );
        }
        // In landscape the readings occupy only part of the screen, so keep
        // the two channel cards side-by-side once there is room for them.
        if (constraints.maxWidth < 450) {
          return Column(
            key: const ValueKey('channel-readings-stacked'),
            children: [
              Expanded(child: _readingPanel(context, ch1)),
              const SizedBox(height: 6),
              Expanded(child: _readingPanel(context, ch2)),
            ],
          );
        }
        return Row(
          key: const ValueKey('channel-readings-side-by-side'),
          children: [
            Expanded(child: _readingPanel(context, ch1)),
            const SizedBox(width: 8),
            Expanded(child: _readingPanel(context, ch2)),
          ],
        );
      },
    );
  }

  Widget _readingPanel(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withAlpha(130)),
      ),
      child: child,
    );
  }
}

class _ChannelReading extends StatelessWidget {
  final String label;
  final double value;
  final String units;
  final double max;
  final int digits;
  final bool isOutOfRange;
  final Color color;
  final DisplayUnit displayUnit;
  final ValueChanged<DisplayUnit>? onDisplayUnitChanged;
  final bool possiblyFloating;
  final bool compact;
  final bool showFloatingValues;
  final bool hasFreshSample;

  const _ChannelReading({
    required this.label,
    required this.value,
    required this.units,
    required this.max,
    required this.digits,
    required this.isOutOfRange,
    required this.color,
    required this.displayUnit,
    this.onDisplayUnitChanged,
    this.possiblyFloating = false,
    this.compact = false,
    this.showFloatingValues = false,
    this.hasFreshSample = true,
  });

  @override
  Widget build(BuildContext context) {
    final hideFloatingValue = possiblyFloating && !showFloatingValues;
    final hideValue = !hasFreshSample || hideFloatingValue;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 6 : 8,
                height: compact ? 6 : 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: compact ? 5 : 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<DisplayUnit>(
                tooltip: 'Display unit',
                initialValue: displayUnit,
                onSelected: onDisplayUnitChanged,
                itemBuilder: (_) => DisplayUnit.values
                    .map(
                      (unit) => PopupMenuItem(
                        value: unit,
                        child: Text(unit.label(units)),
                      ),
                    )
                    .toList(),
                child: compact
                    ? Text(
                        displayUnit.label(units),
                        style: const TextStyle(fontSize: 10),
                      )
                    : Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(displayUnit.label(units)),
                      ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          if (isOutOfRange)
            Text(
              'OUT OF RANGE',
              style: TextStyle(
                fontSize: compact ? 16 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            )
          else
            Row(
              key: ValueKey('reading-value-with-unit-$label'),
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    hideValue ? '—' : _formatValue(),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 20 : 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: color,
                    ),
                  ),
                ),
                if (!hideValue) ...[
                  SizedBox(width: compact ? 5 : 10),
                  Text(
                    _getPrefix() + units,
                    style: TextStyle(
                      fontSize: compact ? 11 : 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          if (!hasFreshSample && !compact)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Waiting for a fresh sample',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
              ),
            )
          else if (possiblyFloating && !compact)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.waves, size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Near zero · possibly floating',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue() {
    if (max == 0) return '0.000';
    final double adjusted = value * displayUnit.scaleFor(value).multiplier;
    return adjusted.toStringAsFixed(digits - 1);
  }

  String _getPrefix() => displayUnit.scaleFor(value).prefix;
}
