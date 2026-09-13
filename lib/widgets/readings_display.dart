import 'package:moosh_revolt/l10n/localization.dart';
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
  final bool ch1MinMaxTracking;
  final bool ch2MinMaxTracking;
  final double? ch1Minimum;
  final double? ch1Maximum;
  final double? ch2Minimum;
  final double? ch2Maximum;
  final ValueChanged<bool>? onCh1MinMaxChanged;
  final ValueChanged<bool>? onCh2MinMaxChanged;
  final VoidCallback? onCh1Configure;
  final VoidCallback? onCh2Configure;
  final bool ch1PossiblyFloating;
  final bool ch2PossiblyFloating;
  final String ch1Units;
  final String ch2Units;
  final double ch1Max;
  final double ch2Max;
  final bool compactLayout;
  final bool stackedLayout;
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
    this.ch1MinMaxTracking = false,
    this.ch2MinMaxTracking = false,
    this.ch1Minimum,
    this.ch1Maximum,
    this.ch2Minimum,
    this.ch2Maximum,
    this.onCh1MinMaxChanged,
    this.onCh2MinMaxChanged,
    this.onCh1Configure,
    this.onCh2Configure,
    this.ch1PossiblyFloating = false,
    this.ch2PossiblyFloating = false,
    this.ch1Units = 'A',
    this.ch2Units = 'V',
    this.ch1Max = 10,
    this.ch2Max = 600,
    this.compactLayout = false,
    this.stackedLayout = false,
    this.showFloatingValues = false,
    this.hasFreshSample = true,
    this.showCh1 = true,
    this.showCh2 = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = false;
    final ch1 = _ChannelReading(
      label: 'CH1 · ${ch1Mode.localizedLabel(context)}',
      value: ch1Value,
      units: ch1Units,
      max: ch1Max,
      digits: Channel.ch1.digits,
      isOutOfRange: ch1OutOfRange,
      displayUnit: ch1DisplayUnit,
      onDisplayUnitChanged: onCh1DisplayUnitChanged,
      minMaxTracking: ch1MinMaxTracking,
      onMinMaxChanged: onCh1MinMaxChanged,
      onConfigure: onCh1Configure,
      minimum: ch1Minimum,
      maximum: ch1Maximum,
      possiblyFloating: ch1PossiblyFloating,
      hasFreshSample: hasFreshSample,
      color: Colors.red,
      compact: isCompact,
      showFloatingValues: showFloatingValues,
    );
    final ch2 = _ChannelReading(
      label: 'CH2 · ${ch2Mode.localizedLabel(context)}',
      value: ch2Value,
      units: ch2Units,
      max: ch2Max,
      digits: Channel.ch2.digits,
      isOutOfRange: ch2OutOfRange,
      displayUnit: ch2DisplayUnit,
      onDisplayUnitChanged: onCh2DisplayUnitChanged,
      minMaxTracking: ch2MinMaxTracking,
      onMinMaxChanged: onCh2MinMaxChanged,
      onConfigure: onCh2Configure,
      minimum: ch2Minimum,
      maximum: ch2Maximum,
      possiblyFloating: ch2PossiblyFloating,
      hasFreshSample: hasFreshSample,
      color: Colors.blue,
      compact: isCompact,
      showFloatingValues: showFloatingValues,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stacked cards only receive about half of this height.  Switch to the
        // compact header before their controls begin competing with the value.
        final compact = compactLayout || constraints.maxHeight < 360;
        final compactCh1 = _ChannelReading(
          label: 'CH1 · ${ch1Mode.localizedLabel(context)}',
          value: ch1Value,
          units: ch1Units,
          max: ch1Max,
          digits: Channel.ch1.digits,
          isOutOfRange: ch1OutOfRange,
          displayUnit: ch1DisplayUnit,
          onDisplayUnitChanged: onCh1DisplayUnitChanged,
          minMaxTracking: ch1MinMaxTracking,
          onMinMaxChanged: onCh1MinMaxChanged,
          onConfigure: onCh1Configure,
          minimum: ch1Minimum,
          maximum: ch1Maximum,
          possiblyFloating: ch1PossiblyFloating,
          hasFreshSample: hasFreshSample,
          color: Colors.red,
          compact: compact,
          showFloatingValues: showFloatingValues,
        );
        final compactCh2 = _ChannelReading(
          label: 'CH2 · ${ch2Mode.localizedLabel(context)}',
          value: ch2Value,
          units: ch2Units,
          max: ch2Max,
          digits: Channel.ch2.digits,
          isOutOfRange: ch2OutOfRange,
          displayUnit: ch2DisplayUnit,
          onDisplayUnitChanged: onCh2DisplayUnitChanged,
          minMaxTracking: ch2MinMaxTracking,
          onMinMaxChanged: onCh2MinMaxChanged,
          onConfigure: onCh2Configure,
          minimum: ch2Minimum,
          maximum: ch2Maximum,
          possiblyFloating: ch2PossiblyFloating,
          hasFreshSample: hasFreshSample,
          color: Colors.blue,
          compact: compact,
          showFloatingValues: showFloatingValues,
        );
        if (!showCh1 && !showCh2) {
          return Center(
            key: ValueKey('channel-readings-none'),
            child: Text(context.l10n.enableChannel),
          );
        }
        if (!showCh1) {
          return _readingPanel(context, compactCh2);
        }
        if (!showCh2) {
          return _readingPanel(context, compactCh1);
        }
        if (stackedLayout || constraints.maxWidth < 450) {
          return Column(
            key: ValueKey('channel-readings-stacked'),
            children: [
              Expanded(
                child: _readingPanel(context, compact ? compactCh1 : ch1),
              ),
              SizedBox(height: 6),
              Expanded(
                child: _readingPanel(context, compact ? compactCh2 : ch2),
              ),
            ],
          );
        }
        if (compact) {
          return Row(
            key: ValueKey('channel-readings-compact'),
            children: [
              Expanded(child: _readingPanel(context, compactCh1)),
              SizedBox(width: 4),
              Expanded(child: _readingPanel(context, compactCh2)),
            ],
          );
        }
        return Row(
          key: ValueKey('channel-readings-side-by-side'),
          children: [
            Expanded(child: _readingPanel(context, ch1)),
            SizedBox(width: 8),
            Expanded(child: _readingPanel(context, ch2)),
          ],
        );
      },
    );
  }

  Widget _readingPanel(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
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
  final bool minMaxTracking;
  final ValueChanged<bool>? onMinMaxChanged;
  final VoidCallback? onConfigure;
  final double? minimum;
  final double? maximum;
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
    this.minMaxTracking = false,
    this.onMinMaxChanged,
    this.onConfigure,
    this.minimum,
    this.maximum,
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
              if (onConfigure != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: 28),
                  icon: Icon(Icons.tune, size: compact ? 14 : 18),
                  tooltip: context.l10n.configureChannel(label),
                  onPressed: onConfigure,
                ),
              if (compact)
                PopupMenuButton<DisplayUnit>(
                  tooltip: context.l10n.unitsHelp,
                  initialValue: displayUnit,
                  onSelected: onDisplayUnitChanged,
                  itemBuilder: (_) => DisplayUnit.values
                      .map(
                        (unit) => PopupMenuItem(
                          value: unit,
                          child: Text(
                            unit == DisplayUnit.auto
                                ? context.l10n.auto
                                : unit.label(units),
                          ),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Text(
                      displayUnit == DisplayUnit.auto
                          ? context.l10n.unitsAuto
                          : displayUnit.label(units),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              if (compact && onMinMaxChanged != null)
                IconButton(
                  isSelected: minMaxTracking,
                  selectedIcon: Icon(Icons.swap_vert, color: color, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: 28),
                  icon: Icon(
                    minMaxTracking ? Icons.swap_vert : Icons.swap_vert_outlined,
                    size: 16,
                  ),
                  tooltip: minMaxTracking
                      ? context.l10n.stopMinMax
                      : context.l10n.trackMinMax,
                  onPressed: () => onMinMaxChanged!(!minMaxTracking),
                ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          if (isOutOfRange)
            Text(
              context.l10n.outOfRange,
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
                    hideValue ? '—' : _formatValue(context),
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
                      fontSize: compact ? 14 : 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          if (!compact)
            Padding(
              padding: EdgeInsets.only(top: compact ? 4 : 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  PopupMenuButton<DisplayUnit>(
                    tooltip: context.l10n.unitsHelp,
                    initialValue: displayUnit,
                    onSelected: onDisplayUnitChanged,
                    itemBuilder: (_) => DisplayUnit.values
                        .map(
                          (unit) => PopupMenuItem(
                            value: unit,
                            child: Text(
                              unit == DisplayUnit.auto
                                  ? context.l10n.auto
                                  : unit.label(units),
                            ),
                          ),
                        )
                        .toList(),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.straighten, size: 14, color: color),
                      label: Text(
                        displayUnit == DisplayUnit.auto
                            ? context.l10n.unitsAuto
                            : context.l10n.unitsValue(displayUnit.label(units)),
                      ),
                    ),
                  ),
                  if (onMinMaxChanged != null)
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        minMaxTracking
                            ? Icons.swap_vert
                            : Icons.swap_vert_outlined,
                        size: compact ? 12 : 14,
                      ),
                      label: Text('Min/Max'),
                      selected: minMaxTracking,
                      tooltip: minMaxTracking
                          ? context.l10n.stopMinMax
                          : context.l10n.trackMinMax,
                      onSelected: onMinMaxChanged,
                    ),
                ],
              ),
            ),
          if (!hasFreshSample && !compact)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                context.l10n.waitingSample,
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
              ),
            )
          else if (possiblyFloating && !compact)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.waves, size: 14, color: Colors.amber.shade700),
                  SizedBox(width: 4),
                  Text(
                    context.l10n.possiblyFloating,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          if (minMaxTracking && minimum != null && maximum != null)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Min ${_formatTrackedValue(context, minimum!)}   Max ${_formatTrackedValue(context, maximum!)}',
                style: TextStyle(
                  fontSize: compact ? 9 : 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(BuildContext context) {
    if (max == 0) return context.formatReading(0, digits - 1);
    final double adjusted = value * displayUnit.scaleFor(value).multiplier;
    return context.formatReading(adjusted, digits - 1);
  }

  String _getPrefix() => displayUnit.scaleFor(value).prefix;

  String _formatTrackedValue(BuildContext context, double trackedValue) {
    final scale = displayUnit.scaleFor(trackedValue);
    return '${context.formatReading(trackedValue * scale.multiplier, 5)}${scale.prefix}$units';
  }
}
