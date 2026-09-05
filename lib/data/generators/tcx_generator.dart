import 'package:xml/xml.dart';
import '../../domain/models/workout_activity.dart';

class TcxGenerator {
  /// Converts a [WorkoutActivity] into a standard Garmin TCX (Training Center Database) XML string.
  static String generate(WorkoutActivity activity) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('TrainingCenterDatabase', nest: () {
      builder.attribute('xmlns', 'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2');
      builder.attribute('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
      builder.attribute('xmlns:ns3', 'http://www.garmin.com/xmlschemas/ActivityExtension/v2');
      builder.attribute('xsi:schemaLocation', 
        'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd '
        'http://www.garmin.com/xmlschemas/ActivityExtension/v2 http://www.garmin.com/xmlschemas/ActivityExtensionv2.xsd'
      );

      builder.element('Activities', nest: () {
        builder.element('Activity', nest: () {
          builder.attribute('Sport', activity.sportType.tcxSportName);

          builder.element('Id', nest: activity.startTime.toUtc().toIso8601String());

          // Lap Element
          builder.element('Lap', nest: () {
            builder.attribute('StartTime', activity.startTime.toUtc().toIso8601String());

            builder.element('TotalTimeSeconds', nest: activity.totalDurationSeconds > 0 
                ? activity.totalDurationSeconds.toString() 
                : activity.duration.inSeconds.toString());
            builder.element('DistanceMeters', nest: activity.totalDistanceMeters.toStringAsFixed(2));
            builder.element('Calories', nest: activity.totalCalories.toString());

            if (activity.avgHeartRate != null) {
              builder.element('AverageHeartRateBpm', nest: () {
                builder.element('Value', nest: activity.avgHeartRate.toString());
              });
            }

            if (activity.maxHeartRate != null) {
              builder.element('MaximumHeartRateBpm', nest: () {
                builder.element('Value', nest: activity.maxHeartRate.toString());
              });
            }

            builder.element('Intensity', nest: 'Active');
            builder.element('TriggerMethod', nest: 'Manual');

            // Track points
            if (activity.trackPoints.isNotEmpty) {
              builder.element('Track', nest: () {
                for (final point in activity.trackPoints) {
                  builder.element('Trackpoint', nest: () {
                    builder.element('Time', nest: point.timestamp.toUtc().toIso8601String());

                    builder.element('Position', nest: () {
                      builder.element('LatitudeDegrees', nest: point.latitude.toStringAsFixed(7));
                      builder.element('LongitudeDegrees', nest: point.longitude.toStringAsFixed(7));
                    });

                    if (point.elevation != null) {
                      builder.element('AltitudeMeters', nest: point.elevation!.toStringAsFixed(2));
                    }

                    if (point.distanceMeters != null) {
                      builder.element('DistanceMeters', nest: point.distanceMeters!.toStringAsFixed(2));
                    }

                    if (point.heartRate != null) {
                      builder.element('HeartRateBpm', nest: () {
                        builder.element('Value', nest: point.heartRate.toString());
                      });
                    }

                    if (point.cadence != null) {
                      builder.element('Cadence', nest: point.cadence.toString());
                    }

                    if (point.speed != null) {
                      builder.element('Extensions', nest: () {
                        builder.element('ns3:TPX', nest: () {
                          builder.element('ns3:Speed', nest: point.speed!.toStringAsFixed(2));
                        });
                      });
                    }
                  });
                }
              });
            }
          });

          // Creator
          builder.element('Creator', nest: () {
            builder.attribute('xsi:type', 'Device_t');
            builder.element('Name', nest: 'Huawei Health');
            builder.element('UnitId', nest: '0');
            builder.element('ProductID', nest: '0');
          });
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }
}
