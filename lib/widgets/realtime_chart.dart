import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moosh_revolt/models/meter_reading.dart';

enum GraphStyle { split, dualAxis, sharedAxis }

/// A real-time scrolling line chart for displaying Mooshimeter readings.
class RealtimeChart extends StatefulWidget {
  final List<LinePoint> ch1Points;
  final List<LinePoint> ch2Points;
  final double ch1Max;
  final double ch2Max;
  final Color ch1Color;
  final Color ch2Color;
  final String ch1Label;
  final String ch2Label;
  final GraphStyle style;

  /// Plots a channel's resistance as a two-state open/continuous trace
  /// instead of ohms.
  final bool ch1Continuity;
  final bool ch2Continuity;

  /// Whether each channel is plotted. A hidden channel keeps its legend
  /// chip, so it can be shown again from the chart itself.
  final bool showCh1;
  final bool showCh2;
  final ValueChanged<bool>? onCh1VisibilityChanged;
  final ValueChanged<bool>? onCh2VisibilityChanged;

  const RealtimeChart({
    super.key,
    required this.ch1Points,
    required this.ch2Points,
    this.ch1Max = 600,
    this.ch2Max = 10,
    this.ch1Color = Colors.red,
    this.ch2Color = Colors.blue,
    this.ch1Label = 'Current (A)',
    this.ch2Label = 'Voltage (V)',
    this.style = GraphStyle.dualAxis,
    this.ch1Continuity = false,
    this.ch2Continuity = false,
    this.showCh1 = true,
    this.showCh2 = true,
    this.onCh1VisibilityChanged,
    this.onCh2VisibilityChanged,
  });

  @override
  State<RealtimeChart> createState() => _RealtimeChartState();
}

class _RealtimeChartState extends State<RealtimeChart> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _plotBackground =>
      _isDark ? const Color(0xFF11151A) : const Color(0xFFF1F3F5);
  Color get _plotBorder =>
      _isDark ? const Color(0xFF30363D) : const Color(0xFFC4CBD3);
  Color get _plotText =>
      _isDark ? const Color(0xFFB7C0CC) : const Color(0xFF334155);
  Color get _gridColor =>
      _isDark ? Colors.white.withAlpha(24) : const Color(0xFFD2D8DE);
  ChartAxisRange _range1 = const ChartAxisRange(-600, 600, 200);
  ChartAxisRange _range2 = const ChartAxisRange(-10, 10, 5);
  ChartAxisRange? _sharedRange;
  List<LinePoint> _ch1Series = const [];
  List<LinePoint> _ch2Series = const [];

  /// Continuity values are 0 (open) and 1 (continuous); the half-step margin
  /// keeps both levels clear of the plot border.
  static const _continuityRange = ChartAxisRange(-0.5, 1.5, 0.5);

  @override
  void initState() {
    super.initState();
    _updateRanges();
  }

  @override
  void didUpdateWidget(covariant RealtimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRanges();
  }

  void _updateRanges() {
    _ch1Series = _series(widget.ch1Points, widget.ch1Continuity);
    _ch2Series = _series(widget.ch2Points, widget.ch2Continuity);
    final ch1 = _extent(_ch1Series);
    final ch2 = _extent(_ch2Series);
    if (widget.ch1Continuity) {
      _range1 = _continuityRange;
    } else if (ch1 != null) {
      _range1 = ChartAxisRange.resolve(ch1.$1, ch1.$2, _range1);
    }
    if (widget.ch2Continuity) {
      _range2 = _continuityRange;
    } else if (ch2 != null) {
      _range2 = ChartAxisRange.resolve(ch2.$1, ch2.$2, _range2);
    }
    if (ch1 != null || ch2 != null) {
      _sharedRange = ChartAxisRange.resolve(
        math.min(ch1?.$1 ?? double.infinity, ch2?.$1 ?? double.infinity),
        math.max(ch1?.$2 ?? -double.infinity, ch2?.$2 ?? -double.infinity),
        _sharedRange,
      );
    }
  }

  /// Overloaded samples (NaN) count as open in a continuity trace.
  static List<LinePoint> _series(
    List<LinePoint> points,
    bool continuity,
  ) => decimateEnvelope(
    continuity
        ? [for (final p in points) LinePoint(p.x, hasContinuity(p.y) ? 1 : 0)]
        : points,
  );

  static (double, double)? _extent(List<LinePoint> points) {
    var min = double.infinity;
    var max = -double.infinity;
    for (final p in points) {
      if (!p.y.isFinite) continue;
      if (p.y < min) min = p.y;
      if (p.y > max) max = p.y;
    }
    return min.isFinite ? (min, max) : null;
  }

  /// Overloaded samples are NaN; a null spot leaves a gap in the line.
  static FlSpot _spot(LinePoint point) =>
      point.y.isFinite ? FlSpot(point.x, point.y) : FlSpot.nullSpot;

  /// The visible time window, shared by every layer so stacked dual-axis
  /// charts scroll in lockstep.
  (double, double) get _xWindow {
    var minX = double.infinity;
    var maxX = -double.infinity;
    for (final points in [widget.ch1Points, widget.ch2Points]) {
      if (points.isEmpty) continue;
      minX = math.min(minX, points.first.x);
      maxX = math.max(maxX, points.last.x);
    }
    if (minX == maxX) return (minX - 0.5, maxX + 0.5);
    return (minX, maxX);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('realtime-chart-${widget.style.name}'),
      decoration: BoxDecoration(
        color: _plotBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _plotBorder),
      ),
      child: Column(
        children: [
          // Legend: each entry toggles its channel's visibility.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _LegendToggle(
                  key: const ValueKey('legend-ch1'),
                  channel: 'CH1',
                  color: widget.ch1Color,
                  label: widget.ch1Label,
                  visible: widget.showCh1,
                  onChanged: widget.onCh1VisibilityChanged,
                ),
                _LegendToggle(
                  key: const ValueKey('legend-ch2'),
                  channel: 'CH2',
                  color: widget.ch2Color,
                  label: widget.ch2Label,
                  visible: widget.showCh2,
                  onChanged: widget.onCh2VisibilityChanged,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _plotBorder),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: !widget.showCh1 && !widget.showCh2
                  ? _placeholder(
                      'Both channels are hidden. Tap CH1 or CH2 above.',
                    )
                  : widget.ch1Points.isEmpty && widget.ch2Points.isEmpty
                  ? _placeholder('Waiting for samples…')
                  : _buildChartArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: _plotText),
    ),
  );

  Widget _ch1Chart({bool showGrid = true}) => LineChart(
    _singleChartData(
      _ch1Series,
      widget.ch1Color,
      _range1,
      widget.ch1Label,
      showGrid: showGrid,
      continuity: widget.ch1Continuity,
    ),
    duration: Duration.zero,
  );

  Widget _ch2Chart({bool rightAxis = false, bool showGrid = true}) => LineChart(
    _singleChartData(
      _ch2Series,
      widget.ch2Color,
      _range2,
      widget.ch2Label,
      rightAxis: rightAxis,
      showGrid: showGrid,
      continuity: widget.ch2Continuity,
    ),
    duration: Duration.zero,
  );

  Widget _buildChartArea() {
    // A single visible channel always gets a full plot with its own axis and
    // grid, whatever the two-channel style is.
    if (!widget.showCh2) return _ch1Chart();
    if (!widget.showCh1) return _ch2Chart();
    switch (widget.style) {
      case GraphStyle.sharedAxis:
        return LineChart(_chartData(), duration: Duration.zero);
      case GraphStyle.split:
        return Column(
          children: [
            Expanded(child: _ch1Chart(showGrid: false)),
            Divider(height: 1, color: _plotBorder),
            Expanded(child: _ch2Chart(showGrid: false)),
          ],
        );
      case GraphStyle.dualAxis:
        return Stack(
          fit: StackFit.expand,
          children: [_ch1Chart(), _ch2Chart(rightAxis: true, showGrid: false)],
        );
    }
  }

  LineChartData _singleChartData(
    List<LinePoint> points,
    Color color,
    ChartAxisRange range,
    String label, {
    bool rightAxis = false,
    bool showGrid = false,
    bool continuity = false,
  }) {
    final spots = points.map(_spot).toList();
    final axisTitles = SideTitles(
      showTitles: true,
      reservedSize: 44,
      interval: range.step,
      getTitlesWidget: (value, meta) {
        final text = continuity ? _continuityLabel(value) : range.format(value);
        return Text(text, style: TextStyle(fontSize: 9, color: _plotText));
      },
    );
    // Both layers of the dual-axis Stack must reserve identical plot gutters.
    // `showTitles: false` collapses the gutter in fl_chart, which lets the
    // overlaid series draw across the other chart's axis labels.
    final blankAxisTitles = SideTitles(
      showTitles: true,
      reservedSize: 64,
      interval: range.step,
      getTitlesWidget: (_, _) => const SizedBox.shrink(),
    );
    final (minX, maxX) = _xWindow;
    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: range.min,
      maxY: range.max,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: showGrid,
        drawVerticalLine: true,
        horizontalInterval: range.step,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: _gridColor, strokeWidth: 0.5),
        getDrawingVerticalLine: (value) =>
            FlLine(color: _gridColor, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: rightAxis ? null : _axisLabel(label, color),
          axisNameSize: rightAxis ? 0 : 20,
          sideTitles: rightAxis ? blankAxisTitles : axisTitles,
        ),
        rightTitles: AxisTitles(
          axisNameWidget: rightAxis ? _axisLabel(label, color) : null,
          axisNameSize: rightAxis ? 20 : 0,
          sideTitles: rightAxis ? axisTitles : blankAxisTitles,
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          isStepLineChart: continuity,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: !rightAxis,
            color: color.withAlpha((0.1 * 255).toInt()),
          ),
        ),
      ],
    );
  }

  LineChartData _chartData() {
    final ch1Spots = _ch1Series.map(_spot).toList();
    final ch2Spots = _ch2Series.map(_spot).toList();
    final range = _sharedRange ?? _range1;
    final (minX, maxX) = _xWindow;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: range.min,
      maxY: range.max,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: range.step,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: _gridColor, strokeWidth: 0.5),
        getDrawingVerticalLine: (value) =>
            FlLine(color: _gridColor, strokeWidth: 0.5),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          axisNameWidget: _axisLabel(
            '${widget.ch1Label} / ${widget.ch2Label}',
            _plotText,
          ),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: range.step,
            getTitlesWidget: (value, meta) {
              return Text(
                range.format(value),
                style: TextStyle(fontSize: 9, color: _plotText),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        // Channel 1
        if (ch1Spots.isNotEmpty)
          LineChartBarData(
            spots: ch1Spots,
            isCurved: false,
            isStepLineChart: widget.ch1Continuity,
            color: widget.ch1Color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: widget.ch1Color.withAlpha((0.1 * 255).toInt()),
            ),
          ),
        // Channel 2
        if (ch2Spots.isNotEmpty)
          LineChartBarData(
            spots: ch2Spots,
            isCurved: false,
            isStepLineChart: widget.ch2Continuity,
            color: widget.ch2Color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: widget.ch2Color.withAlpha((0.1 * 255).toInt()),
            ),
          ),
      ],
    );
  }

  static String _continuityLabel(double value) => switch (value) {
    0 => 'Open',
    1 => 'Cont.',
    _ => '',
  };

  Widget _axisLabel(String label, Color color) => Text(
    label,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
  );
}

class _LegendToggle extends StatelessWidget {
  const _LegendToggle({
    super.key,
    required this.channel,
    required this.color,
    required this.label,
    required this.visible,
    this.onChanged,
  });

  final String channel;
  final Color color;
  final String label;
  final bool visible;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7C0CC)
        : const Color(0xFF334155);
    return Tooltip(
      message: visible ? 'Hide $channel' : 'Show $channel',
      child: FilterChip(
        selected: visible,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: visible ? color : textColor.withAlpha(90)),
        selectedColor: color.withAlpha(36),
        backgroundColor: Colors.transparent,
        avatar: Icon(
          visible ? Icons.visibility : Icons.visibility_off,
          size: 16,
          color: visible ? color : textColor.withAlpha(140),
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: visible ? textColor : textColor.withAlpha(140),
              decoration: visible ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
        onSelected: onChanged,
      ),
    );
  }
}

/// A Y-axis range that stays put while live samples scroll through it.
///
/// Recomputing the axis from the exact min/max of every frame makes the plot
/// rescale (and its labels change) whenever a sample enters or leaves the
/// window. Instead the range snaps to round grid steps, grows immediately when
/// data would leave it, and only shrinks once the data occupies a small part
/// of it.
class ChartAxisRange {
  const ChartAxisRange(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;

  double get span => max - min;

  /// Below this fraction of the current span the axis shrinks to fit again.
  static const shrinkThreshold = 0.4;

  static const _gridLines = 4;

  static ChartAxisRange resolve(
    double dataMin,
    double dataMax,
    ChartAxisRange? previous,
  ) {
    final target = fit(dataMin, dataMax);
    if (previous != null &&
        previous.min <= dataMin &&
        previous.max >= dataMax &&
        target.span >= previous.span * shrinkThreshold) {
      return previous;
    }
    return target;
  }

  /// The tightest round range around the data, with headroom so the trace
  /// never sits on the plot border.
  static ChartAxisRange fit(double dataMin, double dataMax) {
    final dataSpan = dataMax - dataMin;
    final magnitude = math.max(dataMin.abs(), dataMax.abs());
    final padding = math.max(math.max(dataSpan * 0.2, magnitude * 0.1), 1e-9);
    final step = _niceStep((dataSpan + 2 * padding) / _gridLines);
    return ChartAxisRange(
      ((dataMin - padding) / step).floorToDouble() * step,
      ((dataMax + padding) / step).ceilToDouble() * step,
      step,
    );
  }

  static double _niceStep(double rough) {
    final exponent = (math.log(rough) / math.ln10).floorToDouble();
    final base = math.pow(10, exponent).toDouble();
    final fraction = rough / base;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
        ? 2
        : fraction <= 5
        ? 5
        : 10;
    return nice * base;
  }

  /// Formats a tick with just enough decimals to tell neighbouring ticks
  /// apart.
  String format(double value) {
    final decimals = (-(math.log(step) / math.ln10).floor()).clamp(0, 9);
    // Avoid "-0.00" for a tick computed as a tiny negative rounding error.
    final rounded = value.abs() < step / 1000 ? 0.0 : value;
    return rounded.toStringAsFixed(decimals);
  }
}

/// Most spots a series is drawn with. Hours of history at 16 samples/s
/// would otherwise mean tens of thousands of spots per frame.
const maxChartBuckets = 600;

/// Thins [points] to at most two per bucket of equal time, keeping each
/// bucket's minimum and maximum in time order, so spikes and overloads stay
/// visible however long the history is. A bucket with an overload (NaN)
/// keeps the gap.
List<LinePoint> decimateEnvelope(
  List<LinePoint> points, {
  int buckets = maxChartBuckets,
}) {
  if (points.length <= buckets * 2) return points;
  final start = points.first.x;
  final width = (points.last.x - start) / buckets;
  if (width <= 0) return points;
  final result = <LinePoint>[];
  var i = 0;
  for (var bucket = 0; bucket < buckets && i < points.length; bucket++) {
    final end = bucket == buckets - 1
        ? double.infinity
        : start + width * (bucket + 1);
    LinePoint? low;
    LinePoint? high;
    LinePoint? gap;
    for (; i < points.length && points[i].x < end; i++) {
      final point = points[i];
      if (!point.y.isFinite) {
        gap ??= point;
        continue;
      }
      if (low == null || point.y < low.y) low = point;
      if (high == null || point.y > high.y) high = point;
    }
    final kept = [?low, if (high != null && !identical(high, low)) high, ?gap]
      ..sort((a, b) => a.x.compareTo(b.x));
    result.addAll(kept);
  }
  return result;
}

/// A single data point on the chart.
class LinePoint {
  final double x;
  final double y;
  LinePoint(this.x, this.y);
}
