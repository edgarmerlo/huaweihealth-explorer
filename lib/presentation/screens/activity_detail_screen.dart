import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/models/sync_record.dart';
import '../../data/services/export_service.dart';
import '../controllers/workout_provider.dart';
import '../widgets/map_preview_widget.dart';
import '../widgets/telemetry_chart_widget.dart';
import '../widgets/strava_auth_dialog.dart';

class ActivityDetailScreen extends StatefulWidget {
  final WorkoutActivity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _isExporting = false;
  bool _isSyncingStrava = false;

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

  Future<void> _syncToStrava(WorkoutProvider provider) async {
    if (!provider.isStravaConnected) {
      showDialog(
        context: context,
        builder: (_) => StravaAuthDialog(
          onConnectionChanged: () => provider.refresh(),
        ),
      );
      return;
    }

    setState(() => _isSyncingStrava = true);
    try {
      final results = await provider.syncNewToStrava(targetActivities: [widget.activity]);
      if (mounted) {
        if (results['success']! > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploaded to Strava successfully!'), backgroundColor: Colors.green),
          );
        } else if (results['duplicates']! > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Strava detected this as already uploaded (duplicate). Marked as synced.'), backgroundColor: Colors.blue),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed. Check connection.'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncingStrava = false);
    }
  }

  Future<void> _recheckOnStrava(WorkoutProvider provider) async {
    setState(() => _isSyncingStrava = true);
    final exists = await provider.recheckActivityOnStrava(widget.activity);
    if (mounted) {
      setState(() => _isSyncingStrava = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exists 
              ? 'Activity verified on Strava!' 
              : 'Activity was deleted on Strava. Reset to New (ready to re-sync)!'),
          backgroundColor: exists ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final activity = widget.activity;
    final syncStatus = provider.getSyncStatus(activity);
    final syncRecord = provider.getSyncRecord(activity.permanentId);
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
            // Title & Timestamp & Sync Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormatted,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _buildSyncStatusChip(syncStatus),
              ],
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

            // Strava Direct Sync Card
            _buildStravaCard(context, provider, syncStatus, syncRecord),
            const SizedBox(height: 20),

            // Export Section
            Text(
              'Export Files',
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

  Widget _buildSyncStatusChip(SyncStatus status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case SyncStatus.synced:
      case SyncStatus.duplicate:
        bg = const Color(0xFFFC4C02).withValues(alpha: 0.18);
        fg = const Color(0xFFFC4C02);
        icon = Icons.check_circle_rounded;
        text = 'Synced to Strava';
        break;
      case SyncStatus.modified:
        bg = const Color(0xFFFFB300).withValues(alpha: 0.2);
        fg = const Color(0xFFFFB300);
        icon = Icons.edit_note_rounded;
        text = 'Data Modified';
        break;
      case SyncStatus.unsynced:
        bg = const Color(0xFF00E5BE).withValues(alpha: 0.18);
        fg = const Color(0xFF00E5BE);
        icon = Icons.fiber_new_rounded;
        text = 'Ready to Sync';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStravaCard(
    BuildContext context,
    WorkoutProvider provider,
    SyncStatus status,
    SyncRecord? record,
  ) {
    final isSynced = status == SyncStatus.synced || status == SyncStatus.duplicate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFC4C02).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFC4C02).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_rounded, color: Color(0xFFFC4C02)),
              const SizedBox(width: 8),
              const Text(
                'Strava Sync',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (isSynced)
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Re-verify'),
                  onPressed: _isSyncingStrava ? null : () => _recheckOnStrava(provider),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isSynced
                ? 'This activity is recorded in your local ledger as synced with Strava.'
                : 'Upload this activity directly to your Strava profile in the background.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFC4C02),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isSyncingStrava
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded),
              label: Text(
                isSynced ? 'Re-upload to Strava' : 'Upload to Strava',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isSyncingStrava ? null : () => _syncToStrava(provider),
            ),
          ),
        ],
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
