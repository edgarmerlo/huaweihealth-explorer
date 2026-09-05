import 'dart:convert';
import 'dart:math';
import '../../domain/models/activity_type.dart';
import '../../domain/models/track_point.dart';
import '../../domain/models/telemetry_sample.dart';
import '../../domain/models/workout_activity.dart';

class MotionPathParser {
  /// Parses raw JSON content (string or decoded Map/List) into a list of [WorkoutActivity].
  static List<WorkoutActivity> parseJsonContent(dynamic jsonContent, {String? sourceFileName}) {
    final List<WorkoutActivity> activities = [];

    dynamic data;
    if (jsonContent is String) {
      // Clean up potential unquoted keys or invalid trailing commas if needed
      final sanitized = _sanitizeJsonString(jsonContent);
      data = jsonDecode(sanitized);
    } else {
      data = jsonContent;
    }

    if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is Map<String, dynamic>) {
          final activity = _parseSingleActivity(item, index: i, sourceFileName: sourceFileName);
          if (activity != null) {
            activities.add(activity);
          }
        }
      }
    } else if (data is Map<String, dynamic>) {
      // Check if root object has an inner list (e.g. "motionPath", "data", "records", etc.)
      if (data.containsKey('motionPath') && data['motionPath'] is List) {
        for (int i = 0; i < (data['motionPath'] as List).length; i++) {
          final item = data['motionPath'][i];
          if (item is Map<String, dynamic>) {
            final act = _parseSingleActivity(item, index: i, sourceFileName: sourceFileName);
            if (act != null) activities.add(act);
          }
        }
      } else if (data.containsKey('data') && data['data'] is List) {
        for (int i = 0; i < (data['data'] as List).length; i++) {
          final item = data['data'][i];
          if (item is Map<String, dynamic>) {
            final act = _parseSingleActivity(item, index: i, sourceFileName: sourceFileName);
            if (act != null) activities.add(act);
          }
        }
      } else {
        // Single activity object
        final activity = _parseSingleActivity(data, index: 0, sourceFileName: sourceFileName);
        if (activity != null) {
          activities.add(activity);
        }
      }
    }

    // Sort newest first
    activities.sort((a, b) => b.startTime.compareTo(a.startTime));
    return activities;
  }

  static WorkoutActivity? _parseSingleActivity(Map<String, dynamic> map, {required int index, String? sourceFileName}) {
    try {
      final sportTypeCode = map['sportType'] ?? map['sport_type'] ?? map['type'];
      final sportType = ActivityType.fromHuaweiCode(sportTypeCode);

      final startTime = _parseTimestamp(map['startTime'] ?? map['start_time'] ?? map['beginTime']) 
          ?? DateTime.now();
      
      final endTime = _parseTimestamp(map['endTime'] ?? map['end_time']) 
          ?? startTime.add(Duration(seconds: _parseInt(map['totalTime'] ?? map['duration'] ?? map['totalDuration']) ~/ 1000));

      final durationSeconds = _parseDurationSeconds(map, startTime, endTime);
      final distanceMeters = _parseDistanceMeters(map);
      final calories = _parseInt(map['totalCalories'] ?? map['calorie'] ?? map['calories']);

      // Parse Telemetry
      final heartRateSamples = _parseHeartRateSamples(map);
      final cadenceSamples = _parseCadenceSamples(map);
      final altitudeMap = _parseAltitudeMap(map);

      // Parse GPS Trackpoints
      final trackPoints = _parseTrackPoints(
        map, 
        heartRateSamples: heartRateSamples, 
        cadenceSamples: cadenceSamples, 
        altitudeMap: altitudeMap,
      );

      // Calculate summary stats
      final avgHr = _calculateAvgHr(heartRateSamples, trackPoints) ?? _parseIntOrNull(map['avgHeartRate'] ?? map['avg_hr']);
      final maxHr = _calculateMaxHr(heartRateSamples, trackPoints) ?? _parseIntOrNull(map['maxHeartRate'] ?? map['max_hr']);
      
      final elevationStats = _calculateElevationGainLoss(trackPoints);

      final id = map['recordId']?.toString() ?? 
                 map['workoutId']?.toString() ?? 
                 '${startTime.millisecondsSinceEpoch}_$index';

      final title = '${sportType.displayName} - ${_formatDateTimeTitle(startTime)}';

      return WorkoutActivity(
        id: id,
        title: title,
        sportType: sportType,
        startTime: startTime,
        endTime: endTime,
        totalDurationSeconds: durationSeconds,
        totalDistanceMeters: distanceMeters,
        totalCalories: calories,
        avgHeartRate: avgHr,
        maxHeartRate: maxHr,
        totalAscentMeters: elevationStats.$1,
        totalDescentMeters: elevationStats.$2,
        trackPoints: trackPoints,
        heartRateSamples: heartRateSamples,
        cadenceSamples: cadenceSamples,
        sourceFileName: sourceFileName,
        rawMetadata: map,
      );
    } catch (e) {
      return null;
    }
  }

  static List<TrackPoint> _parseTrackPoints(
    Map<String, dynamic> map, {
    required List<HeartRateSample> heartRateSamples,
    required List<CadenceSample> cadenceSamples,
    required Map<int, double> altitudeMap,
  }) {
    final List<TrackPoint> points = [];

    // Huawei stores GPS data under various keys: "lbsDataMap", "pointList", "trackPoints", "attribute", etc.
    dynamic rawLbs = map['lbsDataMap'] ?? 
                     map['pointList'] ?? 
                     map['trackList'] ?? 
                     map['trackPoints'] ?? 
                     map['points'];

    if (rawLbs == null && map.containsKey('attribute')) {
      final attr = map['attribute'];
      if (attr is Map) {
        rawLbs = attr['lbsDataMap'] ?? attr['pointList'];
      }
    }

    if (rawLbs is List) {
      for (final pt in rawLbs) {
        if (pt is Map<String, dynamic>) {
          final lat = _parseDouble(pt['lat'] ?? pt['latitude']);
          final lon = _parseDouble(pt['lon'] ?? pt['longitude'] ?? pt['lng']);
          final alt = _parseDoubleOrNull(pt['alt'] ?? pt['altitude'] ?? pt['elevation']);
          final time = _parseTimestamp(pt['t'] ?? pt['time'] ?? pt['timestamp']);

          if (_isValidGps(lat, lon) && time != null) {
            points.add(TrackPoint(
              latitude: lat,
              longitude: lon,
              elevation: alt,
              timestamp: time,
              speed: _parseDoubleOrNull(pt['speed']),
            ));
          }
        } else if (pt is String) {
          final parsed = _parseLbsString(pt);
          if (parsed != null) points.add(parsed);
        }
      }
    } else if (rawLbs is Map) {
      // Map format: { "timestamp": "lat,lon,alt" } or { "timestamp": {"lat": ..., "lon": ...} }
      rawLbs.forEach((key, val) {
        final time = _parseTimestamp(key);
        if (time != null) {
          if (val is String) {
            final parsed = _parseLbsValueString(val, time);
            if (parsed != null) points.add(parsed);
          } else if (val is Map) {
            final lat = _parseDouble(val['lat'] ?? val['latitude']);
            final lon = _parseDouble(val['lon'] ?? val['longitude'] ?? val['lng']);
            final alt = _parseDoubleOrNull(val['alt'] ?? val['altitude']);
            if (_isValidGps(lat, lon)) {
              points.add(TrackPoint(
                latitude: lat,
                longitude: lon,
                elevation: alt,
                timestamp: time,
              ));
            }
          }
        }
      });
    }

    // Sort chronologically
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Merge Heart Rate, Cadence and Altitude onto trackpoints
    if (points.isNotEmpty) {
      return _enrichTrackPoints(points, heartRateSamples, cadenceSamples, altitudeMap);
    }

    return points;
  }

  static List<TrackPoint> _enrichTrackPoints(
    List<TrackPoint> points,
    List<HeartRateSample> hrSamples,
    List<CadenceSample> cadSamples,
    Map<int, double> altitudeMap,
  ) {
    final List<TrackPoint> enriched = [];
    double cumulativeDistance = 0.0;

    for (int i = 0; i < points.length; i++) {
      final current = points[i];

      // Calculate distance from previous point
      if (i > 0) {
        final prev = points[i - 1];
        final segmentDist = _calculateHaversineDistance(
          prev.latitude, prev.longitude,
          current.latitude, current.longitude,
        );
        cumulativeDistance += segmentDist;
      }

      final epochSec = current.timestamp.millisecondsSinceEpoch ~/ 1000;

      // Find closest Heart Rate sample (within 5 seconds tolerance)
      int? hr = current.heartRate;
      if (hr == null && hrSamples.isNotEmpty) {
        hr = _findClosestHr(epochSec, hrSamples);
      }

      // Find closest Cadence sample
      int? cad = current.cadence;
      if (cad == null && cadSamples.isNotEmpty) {
        cad = _findClosestCadence(epochSec, cadSamples);
      }

      // Elevation fallback from altitude map
      double? alt = current.elevation ?? altitudeMap[epochSec];

      enriched.add(current.copyWith(
        elevation: alt,
        heartRate: hr,
        cadence: cad,
        distanceMeters: cumulativeDistance,
      ));
    }

    return enriched;
  }

  static List<HeartRateSample> _parseHeartRateSamples(Map<String, dynamic> map) {
    final List<HeartRateSample> samples = [];
    dynamic rawHr = map['heartRateList'] ?? 
                    map['hrList'] ?? 
                    map['heartRateDataMap'] ?? 
                    map['h-r'];

    if (rawHr == null && map.containsKey('attribute')) {
      final attr = map['attribute'];
      if (attr is Map) {
        rawHr = attr['heartRateList'] ?? attr['heartRateDataMap'] ?? attr['h-r'];
      }
    }

    if (rawHr is List) {
      for (final item in rawHr) {
        if (item is Map) {
          final time = _parseTimestamp(item['t'] ?? item['time'] ?? item['timestamp']);
          final hr = _parseIntOrNull(item['hr'] ?? item['heartRate'] ?? item['bpm'] ?? item['val']);
          if (time != null && hr != null && hr > 30 && hr < 240) {
            samples.add(HeartRateSample(timestamp: time, bpm: hr));
          }
        }
      }
    } else if (rawHr is Map) {
      rawHr.forEach((key, val) {
        final time = _parseTimestamp(key);
        final hr = _parseIntOrNull(val);
        if (time != null && hr != null && hr > 30 && hr < 240) {
          samples.add(HeartRateSample(timestamp: time, bpm: hr));
        }
      });
    }

    samples.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return samples;
  }

  static List<CadenceSample> _parseCadenceSamples(Map<String, dynamic> map) {
    final List<CadenceSample> samples = [];
    dynamic rawCad = map['cadenceList'] ?? 
                     map['stepRateList'] ?? 
                     map['cadenceDataMap'] ?? 
                     map['s-r'];

    if (rawCad is List) {
      for (final item in rawCad) {
        if (item is Map) {
          final time = _parseTimestamp(item['t'] ?? item['time']);
          final cad = _parseIntOrNull(item['cadence'] ?? item['stepRate'] ?? item['val']);
          if (time != null && cad != null && cad >= 0) {
            samples.add(CadenceSample(timestamp: time, rpm: cad));
          }
        }
      }
    } else if (rawCad is Map) {
      rawCad.forEach((key, val) {
        final time = _parseTimestamp(key);
        final cad = _parseIntOrNull(val);
        if (time != null && cad != null && cad >= 0) {
          samples.add(CadenceSample(timestamp: time, rpm: cad));
        }
      });
    }

    samples.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return samples;
  }

  static Map<int, double> _parseAltitudeMap(Map<String, dynamic> map) {
    final Map<int, double> altMap = {};
    dynamic rawAlti = map['altitudeList'] ?? 
                      map['altiDataMap'] ?? 
                      map['altitudeDataMap'] ?? 
                      map['alti'];

    if (rawAlti is Map) {
      rawAlti.forEach((key, val) {
        final epoch = _parseEpochSeconds(key);
        final alt = _parseDoubleOrNull(val);
        if (epoch != null && alt != null) {
          altMap[epoch] = alt;
        }
      });
    } else if (rawAlti is List) {
      for (final item in rawAlti) {
        if (item is Map) {
          final epoch = _parseEpochSeconds(item['t'] ?? item['time']);
          final alt = _parseDoubleOrNull(item['alt'] ?? item['alti'] ?? item['val']);
          if (epoch != null && alt != null) {
            altMap[epoch] = alt;
          }
        }
      }
    }

    return altMap;
  }

  static TrackPoint? _parseLbsString(String str) {
    // String formats: "lat=37.123;lon=-122.123;alt=15.0;t=1693849200" or "37.123,-122.123,15.0,1693849200"
    try {
      if (str.contains(';')) {
        final parts = str.split(';');
        double? lat, lon, alt;
        DateTime? time;

        for (final p in parts) {
          final kv = p.split('=');
          if (kv.length == 2) {
            final k = kv[0].trim().toLowerCase();
            final v = kv[1].trim();
            if (k == 'lat') lat = double.tryParse(v);
            if (k == 'lon' || k == 'lng') lon = double.tryParse(v);
            if (k == 'alt') alt = double.tryParse(v);
            if (k == 't' || k == 'time') time = _parseTimestamp(v);
          }
        }

        if (lat != null && lon != null && _isValidGps(lat, lon) && time != null) {
          return TrackPoint(latitude: lat, longitude: lon, elevation: alt, timestamp: time);
        }
      } else if (str.contains(',')) {
        final parts = str.split(',');
        if (parts.length >= 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          final alt = parts.length > 2 ? double.tryParse(parts[2].trim()) : null;
          final time = parts.length > 3 ? _parseTimestamp(parts[3].trim()) : null;

          if (lat != null && lon != null && _isValidGps(lat, lon) && time != null) {
            return TrackPoint(latitude: lat, longitude: lon, elevation: alt, timestamp: time);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static TrackPoint? _parseLbsValueString(String val, DateTime time) {
    try {
      final parts = val.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        final alt = parts.length > 2 ? double.tryParse(parts[2].trim()) : null;
        if (lat != null && lon != null && _isValidGps(lat, lon)) {
          return TrackPoint(latitude: lat, longitude: lon, elevation: alt, timestamp: time);
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _isValidGps(double lat, double lon) {
    // Filter out invalid coordinates and Huawei pause/service markers (lat 90, lon -80 or 0,0)
    if (lat == 0.0 && lon == 0.0) return false;
    if (lat >= 89.9 && lon <= -79.9 && lon >= -80.1) return false; // Huawei marker
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  static DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;

    if (val is num) {
      final doubleVal = val.toDouble();
      // Handle scientific notation e.g. 1.712345E9 or 1.712345E12
      if (doubleVal < 1e11) {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch((doubleVal * 1000).round(), isUtc: true).toLocal();
      } else {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(doubleVal.round(), isUtc: true).toLocal();
      }
    }

    final str = val.toString().trim();
    final parsedNum = double.tryParse(str);
    if (parsedNum != null) {
      return _parseTimestamp(parsedNum);
    }

    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      return null;
    }
  }

  static int? _parseEpochSeconds(dynamic val) {
    final dt = _parseTimestamp(val);
    return dt != null ? dt.millisecondsSinceEpoch ~/ 1000 : null;
  }

  static int _parseDurationSeconds(Map<String, dynamic> map, DateTime start, DateTime end) {
    final raw = map['totalTime'] ?? map['duration'] ?? map['totalDuration'] ?? map['sportTime'];
    if (raw != null) {
      final parsed = _parseInt(raw);
      if (parsed > 0) {
        return parsed > 100000 ? parsed ~/ 1000 : parsed;
      }
    }
    final diff = end.difference(start).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static double _parseDistanceMeters(Map<String, dynamic> map) {
    final raw = map['totalDistance'] ?? map['distance'] ?? map['total_distance'];
    if (raw == null) return 0.0;
    final val = _parseDouble(raw);
    // If distance is unusually large (> 100,000 for a run), check if in cm or mm
    if (val > 1000000) {
      return val / 100.0; // cm to m
    }
    return val;
  }

  static int? _calculateAvgHr(List<HeartRateSample> hrSamples, List<TrackPoint> points) {
    if (hrSamples.isNotEmpty) {
      final sum = hrSamples.fold<int>(0, (prev, e) => prev + e.bpm);
      return (sum / hrSamples.length).round();
    }
    final ptsWithHr = points.where((p) => p.heartRate != null).toList();
    if (ptsWithHr.isNotEmpty) {
      final sum = ptsWithHr.fold<int>(0, (prev, e) => prev + e.heartRate!);
      return (sum / ptsWithHr.length).round();
    }
    return null;
  }

  static int? _calculateMaxHr(List<HeartRateSample> hrSamples, List<TrackPoint> points) {
    if (hrSamples.isNotEmpty) {
      return hrSamples.map((e) => e.bpm).reduce(max);
    }
    final ptsWithHr = points.where((p) => p.heartRate != null).toList();
    if (ptsWithHr.isNotEmpty) {
      return ptsWithHr.map((p) => p.heartRate!).reduce(max);
    }
    return null;
  }

  static (double?, double?) _calculateElevationGainLoss(List<TrackPoint> points) {
    final validAltitudes = points.where((p) => p.elevation != null).map((p) => p.elevation!).toList();
    if (validAltitudes.length < 2) return (null, null);

    double gain = 0.0;
    double loss = 0.0;

    for (int i = 1; i < validAltitudes.length; i++) {
      final diff = validAltitudes[i] - validAltitudes[i - 1];
      if (diff > 0.5) {
        gain += diff;
      } else if (diff < -0.5) {
        loss += diff.abs();
      }
    }

    return (gain, loss);
  }

  static int? _findClosestHr(int epochSec, List<HeartRateSample> samples) {
    int? bestHr;
    int minDiff = 6; // max 5 seconds tolerance

    for (final s in samples) {
      final diff = (s.timestamp.millisecondsSinceEpoch ~/ 1000 - epochSec).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestHr = s.bpm;
        if (diff == 0) break;
      }
    }
    return bestHr;
  }

  static int? _findClosestCadence(int epochSec, List<CadenceSample> samples) {
    int? bestCad;
    int minDiff = 6;

    for (final s in samples) {
      final diff = (s.timestamp.millisecondsSinceEpoch ~/ 1000 - epochSec).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestCad = s.rpm;
        if (diff == 0) break;
      }
    }
    return bestCad;
  }

  static double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static String _sanitizeJsonString(String raw) {
    // Trims and cleans whitespace
    return raw.trim();
  }

  static String _formatDateTimeTitle(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static int _parseInt(dynamic val) => _parseIntOrNull(val) ?? 0;

  static int? _parseIntOrNull(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString());
  }

  static double _parseDouble(dynamic val) => _parseDoubleOrNull(val) ?? 0.0;

  static double? _parseDoubleOrNull(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }
}
