import 'package:flutter/material.dart';

/// One jack in use: its label (A, V or Ω) and the channel colour.
typedef JackUse = ({String jack, Color color});

/// The Mooshimeter's four input jacks, laid out as on the case: V at the
/// top, A on the left, Ω on the right and C (common) at the bottom.
///
/// Jacks in [active] are filled with their channel's colour; [dimmed]
/// shows the other channel faintly. C is filled whenever a probe is in use,
/// because every measurement is taken against it.
class MeterJacks extends StatelessWidget {
  const MeterJacks({
    super.key,
    required this.size,
    this.active,
    this.dimmed,
    this.showLabels = true,
    this.fills,
  });

  final double size;
  final JackUse? active;
  final JackUse? dimmed;
  final bool showLabels;

  /// Explicit colours per jack (for example the guide's overview); these
  /// take precedence over [active] and [dimmed].
  final Map<String, Color>? fills;

  static const _positions = {
    'V': Alignment(0, -1),
    'A': Alignment(-1, 0),
    'Ω': Alignment(1, 0),
    'C': Alignment(0, 1),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final jack = size * 0.34;
    final inUse = active != null || dimmed != null;
    return Semantics(
      label: active == null
          ? 'No probes needed'
          : 'Red probe in ${active!.jack}, black probe in C',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            for (final MapEntry(key: label, value: alignment)
                in _positions.entries)
              Align(
                alignment: alignment,
                child: _jack(
                  label,
                  jack,
                  colors,
                  fill:
                      fills?[label] ??
                      switch (label) {
                        _ when label == active?.jack => active!.color,
                        _ when label == dimmed?.jack => dimmed!.color.withAlpha(
                          90,
                        ),
                        'C' when inUse => colors.onSurface,
                        _ => null,
                      },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _jack(
    String label,
    double diameter,
    ColorScheme colors, {
    Color? fill,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(
          color: fill ?? colors.outline,
          width: diameter * 0.08,
        ),
      ),
      child: showLabels
          ? Text(
              label,
              style: TextStyle(
                fontSize: diameter * 0.5,
                height: 1,
                fontWeight: FontWeight.w700,
                color: fill == null ? colors.onSurfaceVariant : colors.surface,
              ),
            )
          : null,
    );
  }
}
