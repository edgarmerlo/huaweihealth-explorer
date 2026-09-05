import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/services/export_service.dart';
import '../widgets/map_preview_widget.dart';
import '../widgets/telemetry_chart_widget.dart';

class ActivityDetailScreen extends StatefulWidget {
  final WorkoutActivity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _isExporting = false;

  Future<void> _export(ExportFormat format) async {
    setState(() => _isExporting = true);
    try {
      await ExportService.shareWorkout(widget.activity, format);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final theme = Theme.of(context);
    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy • HH:mm').format(activity.startTime);

    return Scaffold(
      appBar: AppBar(
        title: Text(activity.sportType.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share GPX',
            onPressed: _isExporting ? null : () => _export(ExportFormat.gpx),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Timestamp
            Text(
              activity.title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              dateFormatted,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Map preview
            MapPreviewWidget(
              trackPoints: activity.trackPoints,
              height: 260,
              isInteractive: true,
            ),
            const SizedBox(height: 20),

            // Primary Stat Grid
            _buildStatGrid(context, activity),
            const SizedBox(height: 20),

            // Telemetry Chart (Elevation & HR)
            TelemetryChartWidget(activity: activity),
            const SizedBox(height: 24),

            // Export Section
            Text(
              'Export Activity',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.file_download_rounded),
                    label: const Text('GPX 1.1'),
                    onPressed: _isExporting ? null : () => _export(ExportFormat.gpx),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.file_download_rounded),
                    label: const Text('TCX'),
                    onPressed: _isExporting ? null : () => _export(ExportFormat.tcx),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.file_download_rounded),
                    label: const Text('FIT'),
                    onPressed: _isExporting ? null : () => _export(ExportFormat.fit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context, WorkoutActivity activity) {
    final isCycling = activity.sportType == ActivityType.outdoorCycling;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          context,
          title: 'Distance',
          value: activity.formattedDistance,
          icon: Icons.straighten_rounded,
          color: Colors.blue,
        ),
        _buildStatCard(
          context,
          title: 'Duration',
          value: activity.formattedDuration,
          icon: Icons.timer_outlined,
          color: Colors.green,
        ),
        _buildStatCard(
          context,
          title: isCycling ? 'Avg Speed' : 'Avg Pace',
          value: isCycling ? '${activity.avgSpeedKmh.toStringAsFixed(1)} km/h' : activity.formattedPace,
          icon: Icons.speed_rounded,
          color: Colors.orange,
        ),
        _buildStatCard(
          context,
          title: 'Calories',
          value: '${activity.totalCalories} kcal',
          icon: Icons.local_fire_department_rounded,
          color: Colors.redAccent,
        ),
        if (activity.avgHeartRate != null)
          _buildStatCard(
            context,
            title: 'Heart Rate',
            value: '${activity.avgHeartRate} bpm ${activity.maxHeartRate != null ? "(Max ${activity.maxHeartRate})" : ""}',
            icon: Icons.favorite_rounded,
            color: Colors.pinkAccent,
          ),
        if (activity.totalAscentMeters != null)
          _buildStatCard(
            context,
            title: 'Elevation Gain',
            value: '+${activity.totalAscentMeters!.toStringAsFixed(0)} m',
            icon: Icons.terrain_rounded,
            color: Colors.indigo,
          ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
