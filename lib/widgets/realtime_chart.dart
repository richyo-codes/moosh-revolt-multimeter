import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
  double _yMin1 = -600;
  double _yMax1 = 600;
  double _yMin2 = -10;
  double _yMax2 = 10;

  @override
  void didUpdateWidget(covariant RealtimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ch1Points.isNotEmpty) {
      double min = double.infinity;
      double max = -double.infinity;
      for (final p in widget.ch1Points) {
        if (p.y < min) min = p.y;
        if (p.y > max) max = p.y;
      }
      final padding = _padding(min, max);
      _yMin1 = min - padding;
      _yMax1 = max + padding;
    }
    if (widget.ch2Points.isNotEmpty) {
      double min = double.infinity;
      double max = -double.infinity;
      for (final p in widget.ch2Points) {
        if (p.y < min) min = p.y;
        if (p.y > max) max = p.y;
      }
      final padding = _padding(min, max);
      _yMin2 = min - padding;
      _yMax2 = max + padding;
    }
  }

  double _padding(double min, double max) {
    final span = max - min;
    final magnitude = math.max(min.abs(), max.abs());
    return math.max(math.max(span * 0.2, magnitude * 0.1), 1e-9);
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
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _LegendDot(
                    color: widget.ch1Color,
                    label: widget.ch1Label,
                  ),
                ),
                const SizedBox(width: 24),
                Flexible(
                  child: _LegendDot(
                    color: widget.ch2Color,
                    label: widget.ch2Label,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _plotBorder),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: widget.ch1Points.isEmpty && widget.ch2Points.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting for samples…',
                        style: TextStyle(color: _plotText),
                      ),
                    )
                  : _buildChartArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea() {
    switch (widget.style) {
      case GraphStyle.sharedAxis:
        return LineChart(
          _chartData(),
          duration: const Duration(milliseconds: 100),
        );
      case GraphStyle.split:
        return Column(
          children: [
            Expanded(
              child: LineChart(
                _singleChartData(
                  widget.ch1Points,
                  widget.ch1Color,
                  _yMin1,
                  _yMax1,
                  widget.ch1Label,
                ),
                duration: const Duration(milliseconds: 100),
              ),
            ),
            Divider(height: 1, color: _plotBorder),
            Expanded(
              child: LineChart(
                _singleChartData(
                  widget.ch2Points,
                  widget.ch2Color,
                  _yMin2,
                  _yMax2,
                  widget.ch2Label,
                ),
                duration: const Duration(milliseconds: 100),
              ),
            ),
          ],
        );
      case GraphStyle.dualAxis:
        return Stack(
          fit: StackFit.expand,
          children: [
            LineChart(
              _singleChartData(
                widget.ch1Points,
                widget.ch1Color,
                _yMin1,
                _yMax1,
                widget.ch1Label,
                showGrid: true,
              ),
              duration: const Duration(milliseconds: 100),
            ),
            LineChart(
              _singleChartData(
                widget.ch2Points,
                widget.ch2Color,
                _yMin2,
                _yMax2,
                widget.ch2Label,
                rightAxis: true,
              ),
              duration: const Duration(milliseconds: 100),
            ),
          ],
        );
    }
  }

  LineChartData _singleChartData(
    List<LinePoint> points,
    Color color,
    double minY,
    double maxY,
    String label, {
    bool rightAxis = false,
    bool showGrid = false,
  }) {
    final spots = points.map((point) => FlSpot(point.x, point.y)).toList();
    final axisTitles = SideTitles(
      showTitles: true,
      reservedSize: 44,
      getTitlesWidget: (value, meta) => Text(
        _formatAxisValue(value),
        style: TextStyle(fontSize: 9, color: _plotText),
      ),
    );
    // Both layers of the dual-axis Stack must reserve identical plot gutters.
    // `showTitles: false` collapses the gutter in fl_chart, which lets the
    // overlaid series draw across the other chart's axis labels.
    final blankAxisTitles = SideTitles(
      showTitles: true,
      reservedSize: 64,
      getTitlesWidget: (_, _) => const SizedBox.shrink(),
    );
    return LineChartData(
      minY: minY,
      maxY: maxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: showGrid,
        drawVerticalLine: true,
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
    final ch1Spots = widget.ch1Points
        .map((point) => FlSpot(point.x, point.y))
        .toList();
    final ch2Spots = widget.ch2Points
        .map((point) => FlSpot(point.x, point.y))
        .toList();

    return LineChartData(
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
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
            getTitlesWidget: (value, meta) {
              return Text(
                _formatAxisValue(value),
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
      minY: ch1Spots.isEmpty
          ? _yMin2
          : ch2Spots.isEmpty
          ? _yMin1
          : math.min(_yMin1, _yMin2),
      maxY: ch1Spots.isEmpty
          ? _yMax2
          : ch2Spots.isEmpty
          ? _yMax1
          : math.max(_yMax1, _yMax2),
    );
  }

  String _formatAxisValue(double value) {
    final magnitude = value.abs();
    final decimals = switch (magnitude) {
      >= 100 => 0,
      >= 10 => 1,
      >= 1 => 2,
      >= 0.1 => 3,
      _ => 4,
    };
    return value.toStringAsFixed(decimals);
  }

  Widget _axisLabel(String label, Color color) => Text(
    label,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB7C0CC)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single data point on the chart.
class LinePoint {
  final double x;
  final double y;
  LinePoint(this.x, this.y);
}
