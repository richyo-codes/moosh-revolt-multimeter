import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Two panes separated by a draggable divider.
///
/// The divider is dragged with the mouse or a finger, nudged with the arrow
/// keys when focused, and double-clicked to restore [defaultFraction]. The
/// fraction is reported through [onChanged] when a drag ends, so callers can
/// persist the layout without writing on every frame.
class ResizableSplit extends StatefulWidget {
  const ResizableSplit({
    super.key,
    required this.axis,
    required this.first,
    required this.second,
    required this.fraction,
    required this.onChanged,
    this.minFraction = 0.15,
    this.maxFraction = 0.7,
    this.defaultFraction = 0.4,
  });

  /// [Axis.horizontal] places the panes side by side.
  final Axis axis;
  final Widget first;
  final Widget second;

  /// Share of the space given to [first].
  final double fraction;
  final ValueChanged<double> onChanged;
  final double minFraction;
  final double maxFraction;
  final double defaultFraction;

  static const handleThickness = 12.0;

  @override
  State<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends State<ResizableSplit> {
  double? _dragFraction;
  bool _hovered = false;
  bool _focused = false;

  double get _fraction => _dragFraction ?? widget.fraction;

  void _commit(double fraction) {
    final clamped = fraction.clamp(widget.minFraction, widget.maxFraction);
    setState(() => _dragFraction = null);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return LayoutBuilder(
      builder: (context, constraints) {
        final total =
            (horizontal ? constraints.maxWidth : constraints.maxHeight) -
            ResizableSplit.handleThickness;
        final firstSize = total * _fraction;
        final colors = Theme.of(context).colorScheme;
        final active = _hovered || _focused || _dragFraction != null;

        final handle = Semantics(
          label: 'Resize readings and chart',
          slider: true,
          value: '${(_fraction * 100).round()}%',
          child: FocusableActionDetector(
            onShowFocusHighlight: (focused) =>
                setState(() => _focused = focused),
            onShowHoverHighlight: (hovered) =>
                setState(() => _hovered = hovered),
            mouseCursor: horizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            shortcuts: {
              SingleActivator(
                horizontal
                    ? LogicalKeyboardKey.arrowLeft
                    : LogicalKeyboardKey.arrowUp,
              ): const _NudgeIntent(
                -0.05,
              ),
              SingleActivator(
                horizontal
                    ? LogicalKeyboardKey.arrowRight
                    : LogicalKeyboardKey.arrowDown,
              ): const _NudgeIntent(
                0.05,
              ),
            },
            actions: {
              _NudgeIntent: CallbackAction<_NudgeIntent>(
                onInvoke: (intent) => _commit(widget.fraction + intent.delta),
              ),
            },
            child: Tooltip(
              message: 'Drag to resize · double-click to reset',
              waitDuration: const Duration(milliseconds: 600),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _commit(widget.defaultFraction),
                onPanUpdate: (details) {
                  if (total <= 0) return;
                  final delta = horizontal
                      ? details.delta.dx
                      : details.delta.dy;
                  setState(() {
                    _dragFraction = (_fraction + delta / total).clamp(
                      widget.minFraction,
                      widget.maxFraction,
                    );
                  });
                },
                onPanEnd: (_) => _commit(_fraction),
                child: SizedBox(
                  width: horizontal ? ResizableSplit.handleThickness : null,
                  height: horizontal ? null : ResizableSplit.handleThickness,
                  child: ColoredBox(
                    color: _focused
                        ? Theme.of(context).focusColor
                        : Colors.transparent,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: horizontal ? 4 : 40,
                        height: horizontal ? 40 : 4,
                        decoration: BoxDecoration(
                          color: active
                              ? colors.primary
                              : colors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final children = [
          SizedBox(
            width: horizontal ? firstSize : null,
            height: horizontal ? null : firstSize,
            child: widget.first,
          ),
          handle,
          Expanded(child: widget.second),
        ];
        return horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
      },
    );
  }
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.delta);
  final double delta;
}
