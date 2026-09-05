import 'package:xml/xml.dart';
import '../../domain/models/workout_activity.dart';

class GpxGenerator {
  /// Converts a [WorkoutActivity] into a standard GPX 1.1 XML string with Garmin extensions.
  static String generate(WorkoutActivity activity) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'Huawei Health Exporter');
      builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');
      builder.attribute('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
      builder.attribute('xmlns:gpxtpx', 'http://www.garmin.com/xmlschemas/TrackPointExtension/v2');
      builder.attribute('xsi:schemaLocation', 
        'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd '
        'http://www.garmin.com/xmlschemas/TrackPointExtension/v2 http://www.garmin.com/xmlschemas/TrackPointExtensionv2.xsd'
      );

      // Metadata
      builder.element('metadata', nest: () {
        builder.element('name', nest: activity.title);
        builder.element('time', nest: activity.startTime.toUtc().toIso8601String());
      });

      // Track
      builder.element('trk', nest: () {
        builder.element('name', nest: activity.title);
        builder.element('type', nest: activity.sportType.gpxActivityType);

        builder.element('trkseg', nest: () {
          for (final point in activity.trackPoints) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', point.latitude.toStringAsFixed(7));
              builder.attribute('lon', point.longitude.toStringAsFixed(7));

              if (point.elevation != null) {
                builder.element('ele', nest: point.elevation!.toStringAsFixed(2));
              }

              builder.element('time', nest: point.timestamp.toUtc().toIso8601String());

              // Garmin TrackPointExtension for Heart Rate & Cadence
              final hasHr = point.heartRate != null;
              final hasCad = point.cadence != null;
              final hasSpeed = point.speed != null;

              if (hasHr || hasCad || hasSpeed) {
                builder.element('extensions', nest: () {
                  builder.element('gpxtpx:TrackPointExtension', nest: () {
                    if (hasHr) {
                      builder.element('gpxtpx:hr', nest: point.heartRate.toString());
                    }
                    if (hasCad) {
                      builder.element('gpxtpx:cad', nest: point.cadence.toString());
                    }
                    if (hasSpeed) {
                      builder.element('gpxtpx:speed', nest: point.speed!.toStringAsFixed(2));
                    }
                  });
                });
              }
            });
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }
}
