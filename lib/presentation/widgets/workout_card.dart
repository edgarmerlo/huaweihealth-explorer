import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/models/sync_record.dart';

class WorkoutCard extends StatelessWidget {
  final WorkoutActivity activity;
  final SyncStatus syncStatus;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onTap;

  const WorkoutCard({
    super.key,
    required this.activity,
    required this.syncStatus,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatted = DateFormat('EEE, MMM d, yyyy • HH:mm').format(activity.startTime);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected 
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon + Title + Status Badge + Checkbox
              Row(
                children: [
                  _buildSportIcon(activity.sportType, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildSyncBadge(context, syncStatus),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectChanged,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Metrics Row: Distance | Duration | Pace | HR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricItem(
                    context,
                    label: 'Distance',
                    value: activity.formattedDistance,
                    icon: Icons.straighten_rounded,
                  ),
                  _buildMetricItem(
                    context,
                    label: 'Duration',
                    value: activity.formattedDuration,
                    icon: Icons.timer_outlined,
                  ),
                  _buildMetricItem(
                    context,
                    label: activity.sportType == ActivityType.outdoorCycling ? 'Avg Speed' : 'Avg Pace',
                    value: activity.sportType == ActivityType.outdoorCycling 
                        ? '${activity.avgSpeedKmh.toStringAsFixed(1)} km/h'
                        : activity.formattedPace,
                    icon: Icons.speed_rounded,
                  ),
                  if (activity.avgHeartRate != null)
                    _buildMetricItem(
                      context,
                      label: 'Avg HR',
                      value: '${activity.avgHeartRate} bpm',
                      icon: Icons.favorite_rounded,
                      iconColor: Colors.redAccent,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge(BuildContext context, SyncStatus status) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (status) {
      case SyncStatus.synced:
      case SyncStatus.duplicate:
        bg = const Color(0xFFFC4C02).withValues(alpha: 0.15);
        fg = const Color(0xFFFC4C02);
        icon = Icons.check_circle_rounded;
        text = 'Strava';
        break;
      case SyncStatus.modified:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.orange.shade800;
        icon = Icons.edit_note_rounded;
        text = 'Modified';
        break;
      case SyncStatus.unsynced:
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
        icon = Icons.fiber_new_rounded;
        text = 'New';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportIcon(ActivityType type, ThemeData theme) {
    IconData icon;
    Color color;

    switch (type) {
      case ActivityType.outdoorRunning:
      case ActivityType.indoorRunning:
      case ActivityType.trailRunning:
        icon = Icons.directions_run_rounded;
        color = Colors.deepOrange;
        break;
      case ActivityType.outdoorCycling:
      case ActivityType.indoorCycling:
        icon = Icons.directions_bike_rounded;
        color = Colors.teal;
        break;
      case ActivityType.walking:
        icon = Icons.directions_walk_rounded;
        color = Colors.blue;
        break;
      case ActivityType.hiking:
        icon = Icons.hiking_rounded;
        color = Colors.brown;
        break;
      case ActivityType.swimming:
        icon = Icons.pool_rounded;
        color = Colors.cyan;
        break;
      default:
        icon = Icons.fitness_center_rounded;
        color = Colors.purple;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
