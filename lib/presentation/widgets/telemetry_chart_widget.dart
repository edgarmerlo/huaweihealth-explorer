import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/workout_activity.dart';

class TelemetryChartWidget extends StatefulWidget {
  final WorkoutActivity activity;

  const TelemetryChartWidget({super.key, required this.activity});

  @override
  State<TelemetryChartWidget> createState() => _TelemetryChartWidgetState();
}

class _TelemetryChartWidgetState extends State<TelemetryChartWidget> {
  int _selectedChart = 0; // 0 = Elevation, 1 = Heart Rate

  @override
  Widget build(BuildContext context) {
    final hasElevation = widget.activity.trackPoints.any((p) => p.elevation != null);
    final hasHr = widget.activity.heartRateSamples.isNotEmpty || 
                  widget.activity.trackPoints.any((p) => p.heartRate != null);

    if (!hasElevation && !hasHr) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedChart == 0 ? 'Elevation Profile (m)' : 'Heart Rate Profile (BPM)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SegmentedButton<int>(
                  segments: [
                    if (hasElevation)
                      const ButtonSegment(value: 0, icon: Icon(Icons.terrain, size: 16), label: Text('Elevation')),
                    if (hasHr)
                      const ButtonSegment(value: 1, icon: Icon(Icons.favorite, size: 16), label: Text('Heart Rate')),
                  ],
                  selected: {_selectedChart},
                  onSelectionChanged: (val) {
                    setState(() {
                      _selectedChart = val.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: _selectedChart == 0 ? _buildElevationChart() : _buildHeartRateChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElevationChart() {
    final validPoints = widget.activity.trackPoints.where((p) => p.elevation != null).toList();
    if (validPoints.isEmpty) {
      return const Center(child: Text('No elevation data available'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < validPoints.length; i++) {
      final p = validPoints[i];
      final x = (p.distanceMeters ?? (i * 100.0)) / 1000.0; // km
      spots.add(FlSpot(x, p.elevation!));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF00E5BE),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00E5BE).withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateChart() {
    final spots = <FlSpot>[];

    if (widget.activity.heartRateSamples.isNotEmpty) {
      final startTime = widget.activity.startTime;
      for (final s in widget.activity.heartRateSamples) {
        final minutes = s.timestamp.difference(startTime).inSeconds / 60.0;
        spots.add(FlSpot(minutes, s.bpm.toDouble()));
      }
    } else {
      final validPoints = widget.activity.trackPoints.where((p) => p.heartRate != null).toList();
      final startTime = widget.activity.startTime;
      for (final p in validPoints) {
        final minutes = p.timestamp.difference(startTime).inSeconds / 60.0;
        spots.add(FlSpot(minutes, p.heartRate!.toDouble()));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No heart rate data recorded'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFFC4C02),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFC4C02).withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
