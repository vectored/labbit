// lib/screens/data_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class DataScreen extends StatefulWidget {
  final String experimentId;
  const DataScreen({super.key, required this.experimentId});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

enum ChartType { line, scatter, bar }

class _DataScreenState extends State<DataScreen> {
  String chartType = 'line';
  bool autoSort = false;
  bool showBestFit = false;
  late final String userId;

  bool _editingX = false;
  bool _editingY = false;
  late TextEditingController _editingXController;
  late TextEditingController _editingYController;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
  }

  CollectionReference get tablesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('experiments')
      .doc(widget.experimentId)
      .collection('tables');

  Future<void> _addTable() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("new table"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: "table name"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                tablesRef.add({'title': ctrl.text.trim(), 'xLabel': 'x', 'yLabel': 'y'});
              }
              Navigator.pop(context);
            },
            child: const Text("create"),
          ),
        ],
      ),
    );
  }

  Future<void> _editAxisLabel(String tableId, String field, String oldVal) async {
    final ctrl = TextEditingController(text: oldVal);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("edit axis label"),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              final newVal = ctrl.text.trim();
              if (newVal.isNotEmpty) tablesRef.doc(tableId).update({field: newVal});
              Navigator.pop(context);
            },
            child: const Text("save"),
          ),
        ],
      ),
    );
  }

  Future<void> _addRow(String tableId) async {
    final xCtrl = TextEditingController();
    final yCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("add row"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: xCtrl, decoration: const InputDecoration(labelText: 'x'), keyboardType: TextInputType.number),
            TextField(controller: yCtrl, decoration: const InputDecoration(labelText: 'y'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              final x = double.tryParse(xCtrl.text.trim()) ?? 0;
              final y = double.tryParse(yCtrl.text.trim()) ?? 0;
              tablesRef.doc(tableId).collection('rows').add({'x': x, 'y': y, 'highlighted': false});
              Navigator.pop(context);
            },
            child: const Text("add"),
          ),
        ],
      ),
    );
  }

  Future<void> _editCell(String tableId, String rowId, String field, double oldVal) async {
    final ctrl = TextEditingController(text: oldVal.toString());
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("edit value"),
        content: TextField(controller: ctrl, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("cancel")),
          TextButton(
            onPressed: () {
              final newVal = double.tryParse(ctrl.text.trim());
              if (newVal != null) tablesRef.doc(tableId).collection('rows').doc(rowId).update({field: newVal});
              Navigator.pop(context);
            },
            child: const Text("save"),
          ),
        ],
      ),
    );
  }

  Map<String, double> _bestFitLine(List<FlSpot> points) {
    if (points.isEmpty) return {'m': 0, 'b': 0};
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    final n = points.length;
    for (final p in points) {
      sumX += p.x;
      sumY += p.y;
      sumXY += p.x * p.y;
      sumX2 += p.x * p.x;
    }
    final denom = (n * sumX2 - sumX * sumX);
    if (denom == 0) return {'m': 0, 'b': sumY / n};
    final m = (n * sumXY - sumX * sumY) / denom;
    final b = (sumY - m * sumX) / n;
    return {'m': m, 'b': b};
  }

  Map<String, double> _computeRangesSafe(List<FlSpot> spots) {
  if (spots.isEmpty) return {'minX': 0, 'maxX': 1, 'minY': 0, 'maxY': 1};

  double minX = spots.first.x;
  double maxX = spots.first.x;
  double minY = spots.first.y;
  double maxY = spots.first.y;

  for (final s in spots) {
    minX = math.min(minX, s.x);
    maxX = math.max(maxX, s.x);
    minY = math.min(minY, s.y);
    maxY = math.max(maxY, s.y);
  }

  // add padding
  final padX = (maxX - minX).abs() * 0.1;
  final padY = (maxY - minY).abs() * 0.1;

  minX -= padX;
  maxX += padX;
  minY -= padY;
  maxY += padY;

  // safety for single-value / zero-range data
  if ((maxY - minY).abs() < 1e-6) {
    minY = 0;
    maxY = (maxY == 0) ? 1 : maxY * 1.2;
  }
  if ((maxX - minX).abs() < 1e-6) {
    minX -= 1;
    maxX += 1;
  }

  return {'minX': minX, 'maxX': maxX, 'minY': minY, 'maxY': maxY};
}


  Future<void> _deleteTable(String tableId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("delete table"),
        content: const Text("are you sure you want to delete this table? this cannot be undone!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("delete")),
        ],
      ),
    );

    if (confirm == true) {
      final rowsSnapshot = await tablesRef.doc(tableId).collection('rows').get();
      for (final row in rowsSnapshot.docs) {
        await tablesRef.doc(tableId).collection('rows').doc(row.id).delete();
      }
      await tablesRef.doc(tableId).delete();
    }
  }

Widget _buildChart(List<FlSpot> spots, String xLabel, String yLabel, String tableId, ChartType type) {
  const double yLabelWidth = 56;
  const double bottomLabelHeight = 44;
  const double chartHeight = 280;
  const double chartWidth = 600;

  if (spots.isEmpty) {
    return SizedBox(
      height: chartHeight + bottomLabelHeight,
      width: chartWidth,
      child: Row(
        children: [
          SizedBox(width: yLabelWidth),
          Expanded(child: Center(child: Text("no data points"))),
        ],
      ),
    );
  }

  final ranges = _computeRangesSafe(spots);
  final minXChart = ranges['minX']!;
  final maxXChart = ranges['maxX']!;
  final minYChart = ranges['minY']!;
  final maxYChart = ranges['maxY']!;

  Widget chartWidget;

  if (type == ChartType.bar) {
    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < spots.length; i++) {
      final s = spots[i];
      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: s.y, width: 18, color: Colors.blueAccent)],
      ));
    }

    final yInterval = math.max(1, ((maxYChart - minYChart) / 5).abs());

    chartWidget = SizedBox(
      height: chartHeight + bottomLabelHeight,
      width: chartWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: yLabelWidth,
            child: Center(
              child: _editingY
                  ? SizedBox(
                      width: 56,
                      child: TextField(
                        controller: _editingYController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            tablesRef.doc(tableId).update({'yLabel': val.trim()});
                          }
                          setState(() => _editingY = false);
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        _editingYController = TextEditingController(text: yLabel);
                        setState(() => _editingY = true);
                      },
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Padding(padding: const EdgeInsets.only(left: 8.0, right: 4.0), child: Text(yLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                    child: BarChart(
                      BarChartData(
                        minY: minYChart,
                        maxY: maxYChart,
                        barGroups: barGroups,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.24), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 46,
                              interval: yInterval.toDouble(),
                              getTitlesWidget: (value, meta) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(value.toInt().toString(), textAlign: TextAlign.right),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < spots.length) return Text(spots[idx].x.toStringAsFixed((spots[idx].x % 1 == 0) ? 0 : 1));
                                return const SizedBox();
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        alignment: BarChartAlignment.spaceAround,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: bottomLabelHeight,
                  child: Center(
                    child: _editingX
                        ? SizedBox(
                            height: 28,
                            width: 120,
                            child: TextField(
                              controller: _editingXController,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  tablesRef.doc(tableId).update({'xLabel': val.trim()});
                                }
                                setState(() => _editingX = false);
                              },
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              _editingXController = TextEditingController(text: xLabel);
                              setState(() => _editingX = true);
                            },
                            child: Text(xLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    } else {
      LineChartBarData series;
      if (type == ChartType.scatter) {
        series = LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 5, color: Colors.blue, strokeWidth: 0, strokeColor: Colors.transparent),
          ),
          belowBarData: BarAreaData(show: false),
        );
      } else {
        series = LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Colors.blue,
          barWidth: 2,
          dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.blue, strokeWidth: 0, strokeColor: Colors.transparent)),
          belowBarData: BarAreaData(show: false),
        );
      }

      final lineBars = <LineChartBarData>[series];
      String? formulaText;
      if (showBestFit && spots.length > 1) {
        final fit = _bestFitLine(spots);
        final m = fit['m']!;
        final b = fit['b']!;
        final fitSpots = [FlSpot(minXChart, m * minXChart + b), FlSpot(maxXChart, m * maxXChart + b)];
        lineBars.add(LineChartBarData(
          spots: fitSpots,
          isCurved: false,
          color: Colors.red,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ));
        formulaText = "y = ${m.toStringAsFixed(2)}x + ${b.toStringAsFixed(2)}";
      }

      final xInterval = math.max(1, ((maxXChart - minXChart) / 5).roundToDouble());
      final yInterval = math.max(1, ((maxYChart - minYChart) / 5).roundToDouble());


      chartWidget = SizedBox(
        height: chartHeight + bottomLabelHeight + (formulaText != null ? 24 : 0),
        width: chartWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: yLabelWidth,
              child: Center(
                child: _editingY
                    ? SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _editingYController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              tablesRef.doc(tableId).update({'yLabel': val.trim()});
                            }
                            setState(() => _editingY = false);
                          },
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          _editingYController = TextEditingController(text: yLabel);
                          setState(() => _editingY = true);
                        },
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Padding(padding: const EdgeInsets.only(left: 8.0, right: 4.0), child: Text(yLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                      child: LineChart(LineChartData(
                        lineBarsData: lineBars,
                        minX: minXChart,
                        maxX: maxXChart,
                        minY: minYChart,
                        maxY: maxYChart,
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.24), strokeWidth: 1)),
                        borderData: FlBorderData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: xInterval.toDouble(),
                              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(value.toInt().toString())),
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 46,
                              interval: yInterval.toDouble(),
                              getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(right: 6), child: Text(value.toInt().toString())),
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) => touchedSpots
                                .map((s) => LineTooltipItem('(${s.x.toStringAsFixed(2)}, ${s.y.toStringAsFixed(2)})', const TextStyle(color: Colors.black)))
                                .toList(),
                          ),
                        ),
                      )),
                    ),
                  ),
                  SizedBox(
                    height: bottomLabelHeight,
                    child: Center(
                      child: _editingX
                          ? SizedBox(
                              height: 28,
                              width: 120,
                              child: TextField(
                                controller: _editingXController,
                                autofocus: true,
                                textAlign: TextAlign.center,
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    tablesRef.doc(tableId).update({'xLabel': val.trim()});
                                  }
                                  setState(() => _editingX = false);
                                },
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(4)),
                              ),
                            )
                          : GestureDetector(
                              onTap: () {
                                _editingXController = TextEditingController(text: xLabel);
                                setState(() => _editingX = true);
                              },
                              child: Text(xLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                    ),
                  ),
                  if (formulaText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(formulaText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return chartWidget;
  }

  Widget _buildTable(List<DocumentSnapshot> rows, String tableId, String xLabel, String yLabel) {
    List<DocumentSnapshot> displayRows = List.from(rows);
    if (autoSort) displayRows.sort((a, b) => ((a['x'] ?? 0) as num).compareTo((b['x'] ?? 0) as num));

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 18, bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editAxisLabel(tableId, 'xLabel', xLabel),
                  child: Center(child: Text(xLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _editAxisLabel(tableId, 'yLabel', yLabel),
                  child: Center(child: Text(yLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final row = displayRows[oldIndex];
            final rowId = row.id;
            final data = row.data() as Map<String, dynamic>? ?? {};
            tablesRef.doc(tableId).collection('rows').doc(rowId).delete();
            tablesRef.doc(tableId).collection('rows').doc().set(data);
          },
          children: [
            for (final r in displayRows)
              Container(
                key: ValueKey(r.id),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editCell(tableId, r.id, 'x', (r['x'] ?? 0).toDouble()),
                          child: Text((r.data() as Map<String, dynamic>?)?['x'].toString() ?? '0', textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editCell(tableId, r.id, 'y', (r['y'] ?? 0).toDouble()),
                          child: Text((r.data() as Map<String, dynamic>?)?['y'].toString() ?? '0', textAlign: TextAlign.center),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => tablesRef.doc(tableId).collection('rows').doc(r.id).delete()),
                      const Icon(Icons.drag_handle, size: 18),
                    ],
                  ),
                  tileColor: ((r.data() as Map<String, dynamic>?)?['highlighted'] ?? false) ? Colors.yellow[100] : Colors.white,
                  onLongPress: () {
                    final highlighted = (r.data() as Map<String, dynamic>?)?['highlighted'] ?? false;
                    tablesRef.doc(tableId).collection('rows').doc(r.id).update({'highlighted': !highlighted});
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () => _addRow(tableId), child: const Text("add row")),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addTable,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: tablesRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final tables = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            children: [
              for (final table in tables)
                StreamBuilder<QuerySnapshot>(
                  stream: tablesRef.doc(table.id).collection('rows').snapshots(),
                  builder: (context, rowSnap) {
                    final rows = rowSnap.data?.docs ?? [];
                    final xLabel = table['xLabel'] ?? 'x';
                    final yLabel = table['yLabel'] ?? 'y';
                    final spots = rows.map((r) => FlSpot((r['x'] ?? 0).toDouble(), (r['y'] ?? 0).toDouble())).toList();

                    return ExpansionTile(
                      title: Text(table['title'] ?? 'untitled'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Text("chart: "),
                                  DropdownButton<String>(
                                    value: chartType,
                                    items: const [
                                      DropdownMenuItem(value: 'line', child: Text('line')),
                                      DropdownMenuItem(value: 'scatter', child: Text('scatter')),
                                      DropdownMenuItem(value: 'bar', child: Text('bar')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => chartType = val);
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text("best-fit: "),
                                  Switch(value: showBestFit, onChanged: (v) => setState(() => showBestFit = v)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text("autosort: "),
                                  Switch(value: autoSort, onChanged: (v) => setState(() => autoSort = v)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteTable(table.id),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildChart(spots, xLabel, yLabel, table.id, chartType == 'line'
                              ? ChartType.line
                              : chartType == 'scatter'
                                  ? ChartType.scatter
                                  : ChartType.bar),
                        ),
                        const SizedBox(height: 12),
                        _buildTable(rows, table.id, xLabel, yLabel),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
