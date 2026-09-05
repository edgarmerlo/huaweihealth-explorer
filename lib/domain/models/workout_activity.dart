import 'activity_type.dart';
import 'track_point.dart';
import 'telemetry_sample.dart';

class WorkoutLap {
  final int index;
  final DateTime startTime;
  final DateTime endTime;
  final double totalTimeSeconds;
  final double distanceMeters;
  final int? calories;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final List<TrackPoint> trackPoints;

  const WorkoutLap({
    required this.index,
    required this.startTime,
    required this.endTime,
    required this.totalTimeSeconds,
    required this.distanceMeters,
    this.calories,
    this.avgHeartRate,
    this.maxHeartRate,
    this.trackPoints = const [],
  });
}

class WorkoutActivity {
  final String id;
  final String title;
  final ActivityType sportType;
  final DateTime startTime;
  final DateTime endTime;
  final int totalDurationSeconds;
  final double totalDistanceMeters;
  final int totalCalories;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final double? totalAscentMeters;
  final double? totalDescentMeters;
  final List<TrackPoint> trackPoints;
  final List<HeartRateSample> heartRateSamples;
  final List<CadenceSample> cadenceSamples;
  final List<WorkoutLap> laps;
  final String? sourceFileName;
  final Map<String, dynamic> rawMetadata;

  const WorkoutActivity({
    required this.id,
    required this.title,
    required this.sportType,
    required this.startTime,
    required this.endTime,
    required this.totalDurationSeconds,
    required this.totalDistanceMeters,
    required this.totalCalories,
    this.avgHeartRate,
    this.maxHeartRate,
    this.totalAscentMeters,
    this.totalDescentMeters,
    this.trackPoints = const [],
    this.heartRateSamples = const [],
    this.cadenceSamples = const [],
    this.laps = const [],
    this.sourceFileName,
    this.rawMetadata = const {},
  });

  bool get hasGps => trackPoints.isNotEmpty;

  double get distanceKm => totalDistanceMeters / 1000.0;

  double get distanceMiles => totalDistanceMeters / 1609.344;

  Duration get duration => Duration(seconds: totalDurationSeconds > 0 
      ? totalDurationSeconds 
      : endTime.difference(startTime).inSeconds);

  /// Average speed in km/h
  double get avgSpeedKmh {
    if (totalDurationSeconds <= 0) return 0.0;
    return (totalDistanceMeters / 1000.0) / (totalDurationSeconds / 3600.0);
  }

  /// Average pace in seconds per kilometer
  double get avgPaceSecPerKm {
    if (totalDistanceMeters <= 0) return 0.0;
    return totalDurationSeconds / (totalDistanceMeters / 1000.0);
  }

  /// Formatted pace e.g. "5:32 /km"
  String get formattedPace {
    final paceSec = avgPaceSecPerKm;
    if (paceSec <= 0 || paceSec > 3600) return '--:--';
    final minutes = paceSec ~/ 60;
    final seconds = (paceSec % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
  }

  /// Formatted duration e.g. "01:24:12" or "45:10"
  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Permanent entity identifier (guaranteed stable even across edits)
  String get permanentId {
    if (id.isNotEmpty && !id.contains('sample_')) return id;
    return 'huawei_${startTime.toUtc().millisecondsSinceEpoch}';
  }

  /// Content version hash to detect when an activity has been edited/recalibrated in Huawei Health
  String get contentHash {
    return '${sportType.name}_${startTime.toUtc().millisecondsSinceEpoch}_${totalDistanceMeters.round()}_${totalDurationSeconds}_${totalCalories}_${trackPoints.length}_${avgHeartRate ?? 0}';
  }

  /// Unique external file name used for Strava cloud tagging (e.g. huawei_1693849200000.fit)
  String get externalFileName => '$permanentId.fit';

  /// Formatted distance e.g. "5.42 km"
  String get formattedDistance {
    return '${distanceKm.toStringAsFixed(2)} km';
  }
}
