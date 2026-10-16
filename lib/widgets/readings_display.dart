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
  final double? ch1Average;
  final double? ch2Average;
  final VoidCallback? onCh1MinMaxReset;
  final VoidCallback? onCh2MinMaxReset;
  final ValueChanged<bool>? onCh1MinMaxChanged;
  final ValueChanged<bool>? onCh2MinMaxChanged;
  final VoidCallback? onCh1Configure;
  final VoidCallback? onCh2Configure;
  final bool ch1PossiblyFloating;
  final bool ch2PossiblyFloating;
  final String ch1Units;
  final String ch2Units;

  /// Full scale of each channel's active range, in its display unit.
  final double? ch1Max;
  final double? ch2Max;

  /// Digits the meter resolves at its current sample rate and depth.
  final int significantDigits;

  /// Each channel's active range, for example "Auto · 60 V".
  final String? ch1RangeLabel;
  final String? ch2RangeLabel;
  final bool compactLayout;
  final bool stackedLayout;
  final bool showFloatingValues;
  final bool hasFreshSample;
  final bool showCh1;
  final bool showCh2;

  /// Shows a hidden channel again (0 = CH1, 1 = CH2).
  final ValueChanged<int>? onShowChannel;

  /// A third card for the math channel, when one is selected.
  final Widget? math;

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
    this.ch1Average,
    this.ch2Average,
    this.onCh1MinMaxReset,
    this.onCh2MinMaxReset,
    this.onCh1MinMaxChanged,
    this.onCh2MinMaxChanged,
    this.onCh1Configure,
    this.onCh2Configure,
    this.ch1PossiblyFloating = false,
    this.ch2PossiblyFloating = false,
    this.ch1Units = 'A',
    this.ch2Units = 'V',
    this.ch1Max,
    this.ch2Max,
    this.significantDigits = 5,
    this.ch1RangeLabel,
    this.ch2RangeLabel,
    this.compactLayout = false,
    this.stackedLayout = false,
    this.showFloatingValues = false,
    this.hasFreshSample = true,
    this.showCh1 = true,
    this.showCh2 = true,
    this.onShowChannel,
    this.math,
  });

  Widget _reading(int channel, {required bool compact}) {
    final ch1 = channel == 0;
    final mode = ch1 ? ch1Mode : ch2Mode;
    return _ChannelReading(
      label: 'CH${channel + 1} · ${mode.label}',
      value: ch1 ? ch1Value : ch2Value,
      units: ch1 ? ch1Units : ch2Units,
      max: ch1 ? ch1Max : ch2Max,
      digits: significantDigits,
      isOutOfRange: ch1 ? ch1OutOfRange : ch2OutOfRange,
      displayUnit: ch1 ? ch1DisplayUnit : ch2DisplayUnit,
      onDisplayUnitChanged: ch1
          ? onCh1DisplayUnitChanged
          : onCh2DisplayUnitChanged,
      minMaxTracking: ch1 ? ch1MinMaxTracking : ch2MinMaxTracking,
      onMinMaxChanged: ch1 ? onCh1MinMaxChanged : onCh2MinMaxChanged,
      onConfigure: ch1 ? onCh1Configure : onCh2Configure,
      minimum: ch1 ? ch1Minimum : ch2Minimum,
      maximum: ch1 ? ch1Maximum : ch2Maximum,
      average: ch1 ? ch1Average : ch2Average,
      onMinMaxReset: ch1 ? onCh1MinMaxReset : onCh2MinMaxReset,
      possiblyFloating: ch1 ? ch1PossiblyFloating : ch2PossiblyFloating,
      hasFreshSample: hasFreshSample,
      color: ch1 ? Colors.red : Colors.blue,
      compact: compact,
      showFloatingValues: showFloatingValues,
      rangeLabel: ch1 ? ch1RangeLabel : ch2RangeLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Stacked cards only receive about half of this height.  Switch to the
        // compact header before their controls begin competing with the value.
        final compact = compactLayout || constraints.maxHeight < 360;
        final compactCh1 = _reading(0, compact: compact);
        final compactCh2 = _reading(1, compact: compact);
        final cards = [
          if (showCh1) _readingPanel(context, compactCh1),
          if (showCh2) _readingPanel(context, compactCh2),
          if (math case final math?) _readingPanel(context, math),
        ];
        if (!showCh1 && !showCh2 && math == null) {
          return Center(
            key: const ValueKey('channel-readings-none'),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text('Both channels are hidden'),
                if (onShowChannel != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => onShowChannel!(0),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Show CH1'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onShowChannel!(1),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Show CH2'),
                  ),
                ],
              ],
            ),
          );
        }
        if (cards.length == 1) return cards.single;
        List<Widget> spaced(double gap, Axis axis) => [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0)
              SizedBox(
                width: axis == Axis.horizontal ? gap : null,
                height: axis == Axis.vertical ? gap : null,
              ),
            Expanded(child: cards[i]),
          ],
        ];
        if (stackedLayout || constraints.maxWidth < 450) {
          return Column(
            key: const ValueKey('channel-readings-stacked'),
            children: spaced(6, Axis.vertical),
          );
        }
        return Row(
          key: ValueKey(
            compact
                ? 'channel-readings-compact'
                : 'channel-readings-side-by-side',
          ),
          children: spaced(compact ? 4 : 8, Axis.horizontal),
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
  final double? max;
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

  /// Mean of the tracked samples.
  final double? average;
  final VoidCallback? onMinMaxReset;
  final bool possiblyFloating;
  final bool compact;
  final bool showFloatingValues;
  final bool hasFreshSample;

  /// The active range, for example "Auto · 60 V"; tapping it configures
  /// the channel.
  final String? rangeLabel;

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
    this.average,
    this.onMinMaxReset,
    this.possiblyFloating = false,
    this.compact = false,
    this.showFloatingValues = false,
    this.hasFreshSample = true,
    this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
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
                  // At least 40 px, so the control is easy to hit on touch
                  // screens even in compact cards.
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: Icon(Icons.tune, size: compact ? 18 : 20),
                  tooltip: 'Configure $label',
                  onPressed: onConfigure,
                ),
              if (compact) _compactMenu(),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          // A meter's main affordance is the number: in a roomy card it
          // grows to fill the space, in a tight one it shrinks to fit.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: compact
                  ? _valueRow(context, fontSize: 64, unitSize: 28)
                  : _valueRow(context, fontSize: 96, unitSize: 36),
            ),
          ),
          if (!compact)
            Padding(
              padding: EdgeInsets.only(top: compact ? 4 : 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (rangeLabel != null)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.speed, size: 14, color: color),
                      label: Text(rangeLabel!),
                      tooltip: 'Change measurement and range',
                      onPressed: onConfigure,
                    ),
                  PopupMenuButton<DisplayUnit>(
                    tooltip: 'Display units: Auto follows the active range',
                    initialValue: displayUnit,
                    onSelected: onDisplayUnitChanged,
                    itemBuilder: (_) => DisplayUnit.choicesFor(units)
                        .map(
                          (unit) => PopupMenuItem(
                            value: unit,
                            child: Text(unit.label(units)),
                          ),
                        )
                        .toList(),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.straighten, size: 14, color: color),
                      label: Text(
                        displayUnit == DisplayUnit.auto
                            ? 'Units: Auto'
                            : 'Units: ${displayUnit.label(units)}',
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
                      label: const Text('Min/Max'),
                      selected: minMaxTracking,
                      tooltip: minMaxTracking
                          ? 'Stop min/max tracking'
                          : 'Track minimum and maximum values',
                      onSelected: onMinMaxChanged,
                    ),
                ],
              ),
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
          if (minMaxTracking && minimum != null && maximum != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Min ${_formatTrackedValue(minimum!)} · '
                      'Avg ${_formatTrackedValue(average ?? minimum!)} · '
                      'Max ${_formatTrackedValue(maximum!)}',
                      key: ValueKey('min-max-$label'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 10 : 12,
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onMinMaxReset != null && !compact)
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      tooltip: 'Reset min, average and max',
                      onPressed: onMinMaxReset,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueRow(
    BuildContext context, {
    required double fontSize,
    required double unitSize,
  }) {
    if (isOutOfRange && hasFreshSample) {
      return Tooltip(
        message: 'Overload: the input exceeds the selected range',
        child: Text(
          'OL',
          key: ValueKey('reading-overload-$label'),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: Colors.orange.shade700,
          ),
        ),
      );
    }
    final hideValue =
        !hasFreshSample || (possiblyFloating && !showFloatingValues);
    return Row(
      key: ValueKey('reading-value-with-unit-$label'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          hideValue ? '—' : _formatValue(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
        if (!hideValue) ...[
          SizedBox(width: fontSize * 0.2),
          Text(
            _getPrefix() + units,
            style: TextStyle(
              fontSize: unitSize,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// One 40 px menu for the compact card's secondary controls: units and
  /// min/max tracking.
  Widget _compactMenu() {
    return PopupMenuButton<String>(
      tooltip: 'More options for $label',
      icon: const Icon(Icons.more_vert, size: 20),
      constraints: const BoxConstraints(minWidth: 200),
      onSelected: (value) {
        if (value.startsWith('unit:')) {
          final name = value.substring(5);
          onDisplayUnitChanged?.call(
            DisplayUnit.values.firstWhere((u) => u.name == name),
          );
        } else if (value == 'track') {
          onMinMaxChanged?.call(!minMaxTracking);
        } else if (value == 'reset') {
          onMinMaxReset?.call();
        }
      },
      itemBuilder: (_) => [
        for (final unit in DisplayUnit.choicesFor(units))
          CheckedPopupMenuItem(
            value: 'unit:${unit.name}',
            checked: unit == displayUnit,
            child: Text('Units: ${unit.label(units)}'),
          ),
        if (onMinMaxChanged != null) ...[
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'track',
            checked: minMaxTracking,
            child: const Text('Track min/avg/max'),
          ),
          PopupMenuItem(
            value: 'reset',
            enabled: minMaxTracking && onMinMaxReset != null,
            child: const Text('Reset min/avg/max'),
          ),
        ],
      ],
    );
  }

  ReadingFormat get _format => ReadingFormat(
    units: units,
    fullScale: max,
    significantDigits: digits,
    displayUnit: displayUnit,
  );

  String _formatValue() => _format.number(value);

  String _getPrefix() => _format.scaleFor(value).prefix;

  String _formatTrackedValue(double trackedValue) =>
      _format.format(trackedValue);
}
