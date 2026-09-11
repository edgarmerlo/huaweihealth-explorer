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
          color: isSelected ? const Color(0xFF00E5BE) : const Color(0xFF30363D),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected 
          ? const Color(0xFF00E5BE).withValues(alpha: 0.08)
          : const Color(0xFF161B22),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFFF0F6FC),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectChanged,
                    activeColor: const Color(0xFF00E5BE),
                    checkColor: const Color(0xFF0B0E14),
                    side: const BorderSide(color: Color(0xFF8B949E), width: 1.5),
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
                      iconColor: const Color(0xFFFC4C02),
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
        bg = const Color(0xFFFC4C02).withValues(alpha: 0.18);
        fg = const Color(0xFFFC4C02);
        icon = Icons.check_circle_rounded;
        text = 'Strava';
        break;
      case SyncStatus.modified:
        bg = const Color(0xFFFFB300).withValues(alpha: 0.2);
        fg = const Color(0xFFFFB300);
        icon = Icons.edit_note_rounded;
        text = 'Modified';
        break;
      case SyncStatus.unsynced:
        bg = const Color(0xFF00E5BE).withValues(alpha: 0.18);
        fg = const Color(0xFF00E5BE);
        icon = Icons.fiber_new_rounded;
        text = 'New';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3.5),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
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
