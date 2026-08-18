import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moosh_revolt/widgets/realtime_chart.dart';

/// Full-screen graphing view for detailed data analysis.
class GraphScreen extends StatefulWidget {
  final List<LinePoint> ch1Points;
  final List<LinePoint> ch2Points;

  const GraphScreen({
    super.key,
    required this.ch1Points,
    required this.ch2Points,
  });

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _graphDuration = 60; // seconds to show
  late final List<LinePoint> _ch1Points;
  late final List<LinePoint> _ch2Points;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ch1Points = List.of(widget.ch1Points);
    _ch2Points = List.of(widget.ch2Points);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph View'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'Ch1'),
            Tab(text: 'Ch2'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _exportData,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() {
              _ch1Points.clear();
              _ch2Points.clear();
            }),
            tooltip: 'Clear Data',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Live view - both channels
          Padding(
            padding: const EdgeInsets.all(12),
            child: RealtimeChart(
              ch1Points: _filterPoints(_ch1Points),
              ch2Points: _filterPoints(_ch2Points),
              ch1Color: Colors.red,
              ch2Color: Colors.blue,
            ),
          ),
          // Channel 1 only
          Padding(
            padding: const EdgeInsets.all(12),
            child: RealtimeChart(
              ch1Points: _filterPoints(_ch1Points),
              ch2Points: const [],
              ch1Color: Colors.red,
            ),
          ),
          // Channel 2 only
          Padding(
            padding: const EdgeInsets.all(12),
            child: RealtimeChart(
              ch1Points: const [],
              ch2Points: _filterPoints(_ch2Points),
              ch2Color: Colors.blue,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Points: ${_ch1Points.length}',
              style: const TextStyle(fontSize: 13),
            ),
            Row(
              children: [
                _durationButton(30),
                const SizedBox(width: 4),
                _durationButton(60),
                const SizedBox(width: 4),
                _durationButton(300),
                const SizedBox(width: 4),
                _durationButton(0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<LinePoint> _filterPoints(List<LinePoint> points) {
    if (_graphDuration == 0) return points;
    if (points.isEmpty) return points;
    final lastX = points.last.x;
    final cutoff = lastX - _graphDuration.toDouble();
    return points.where((p) => p.x >= cutoff).toList();
  }

  Widget _durationButton(int seconds) {
    final isSelected = _graphDuration == seconds;
    return FilterChip(
      label: Text(seconds == 0 ? 'All' : '$seconds'),
      selected: isSelected,
      onSelected: (_) => setState(() => _graphDuration = seconds),
    );
  }

  Future<void> _exportData() async {
    if (_ch1Points.isEmpty) return;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/Mooshimeter');
    if (!await directory.exists()) await directory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/mooshimeter_graph_$stamp.csv');
    final rows = <String>['elapsed_s,current_a,voltage_v'];
    for (var i = 0; i < _ch1Points.length; i++) {
      rows.add('${_ch1Points[i].x},${_ch1Points[i].y},${_ch2Points[i].y}');
    }
    await file.writeAsString('${rows.join('\n')}\n');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved ${file.path}')));
  }
}
