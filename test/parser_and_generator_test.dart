import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:huawei_health_export/domain/models/activity_type.dart';
import 'package:huawei_health_export/data/parsers/motion_path_parser.dart';
import 'package:huawei_health_export/data/parsers/huawei_archive_parser.dart';
import 'package:huawei_health_export/data/generators/gpx_generator.dart';
import 'package:huawei_health_export/data/generators/tcx_generator.dart';
import 'package:huawei_health_export/data/generators/fit_generator.dart';
import 'package:xml/xml.dart';

void main() {
  group('Huawei MotionPathParser Tests', () {
    test('parses standard Huawei JSON activity with GPS, HR, Altitude, and Cadence', () {
      final sampleJson = [
        {
          "recordId": "1693849200000",
          "sportType": 283, // Outdoor Run
          "startTime": 1693849200000,
          "endTime": 1693851000000,
          "totalTime": 1800000, // 30 mins
          "totalDistance": 5000.0, // 5 km
          "totalCalories": 350,
          "avgHeartRate": 155,
          "maxHeartRate": 178,
          "pointList": [
            {
              "lat": 37.774929,
              "lon": -122.419416,
              "alt": 15.2,
              "t": 1693849200000,
              "speed": 2.8
            },
            {
              "lat": 37.775500,
              "lon": -122.418000,
              "alt": 18.4,
              "t": 1693849800000,
              "speed": 2.9
            },
            {
              "lat": 37.776200,
              "lon": -122.417000,
              "alt": 21.0,
              "t": 1693850400000,
              "speed": 2.7
            }
          ],
          "heartRateList": [
            {"t": 1693849200000, "hr": 142},
            {"t": 1693849800000, "hr": 158},
            {"t": 1693850400000, "hr": 165}
          ],
          "cadenceList": [
            {"t": 1693849200000, "cadence": 160},
            {"t": 1693849800000, "cadence": 168},
            {"t": 1693850400000, "cadence": 172}
          ]
        }
      ];

      final activities = MotionPathParser.parseJsonContent(sampleJson);
      expect(activities.length, 1);

      final act = activities.first;
      expect(act.sportType, ActivityType.outdoorRunning);
      expect(act.distanceKm, 5.0);
      expect(act.totalDurationSeconds, 1800);
      expect(act.totalCalories, 350);
      expect(act.trackPoints.length, 3);

      // Check first trackpoint enriched metrics
      final p1 = act.trackPoints.first;
      expect(p1.latitude, 37.774929);
      expect(p1.longitude, -122.419416);
      expect(p1.elevation, 15.2);
      expect(p1.heartRate, 142);
      expect(p1.cadence, 160);
    });

    test('filters out Huawei pause/service markers (lat 90, lon -80)', () {
      final sampleJson = [
        {
          "sportType": 1,
          "startTime": 1693849200,
          "endTime": 1693849300,
          "pointList": [
            {"lat": 40.7128, "lon": -74.0060, "t": 1693849200},
            {"lat": 90.0, "lon": -80.0, "t": 1693849250}, // Huawei pause marker
            {"lat": 40.7135, "lon": -74.0055, "t": 1693849300}
          ]
        }
      ];

      final activities = MotionPathParser.parseJsonContent(sampleJson);
      expect(activities.first.trackPoints.length, 2);
      expect(activities.first.trackPoints.any((p) => p.latitude == 90.0), isFalse);
    });
  });

  group('Exporters Tests', () {
    final mockActivity = MotionPathParser.parseJsonContent([
      {
        "recordId": "test_1",
        "sportType": 283,
        "startTime": 1693849200000,
        "endTime": 1693851000000,
        "totalTime": 1800000,
        "totalDistance": 5000.0,
        "totalCalories": 350,
        "avgHeartRate": 155,
        "maxHeartRate": 178,
        "pointList": [
          {"lat": 37.774929, "lon": -122.419416, "alt": 15.2, "t": 1693849200000, "speed": 2.8},
          {"lat": 37.776200, "lon": -122.417000, "alt": 21.0, "t": 1693850400000, "speed": 2.7}
        ],
        "heartRateList": [
          {"t": 1693849200000, "hr": 142},
          {"t": 1693850400000, "hr": 165}
        ]
      }
    ]).first;

    test('GpxGenerator produces valid GPX 1.1 XML with HR extensions', () {
      final gpx = GpxGenerator.generate(mockActivity);
      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('<trkpt lat="37.7749290" lon="-122.4194160">'));
      expect(gpx, contains('<ele>15.20</ele>'));
      expect(gpx, contains('<gpxtpx:hr>142</gpxtpx:hr>'));

      // Validate XML structure
      final doc = XmlDocument.parse(gpx);
      expect(doc.findAllElements('trkpt').length, 2);
    });

    test('TcxGenerator produces valid Garmin TCX XML', () {
      final tcx = TcxGenerator.generate(mockActivity);
      expect(tcx, contains('<TrainingCenterDatabase'));
      expect(tcx, contains('Sport="Running"'));
      expect(tcx, contains('<DistanceMeters>5000.00</DistanceMeters>'));
      expect(tcx, contains('<LatitudeDegrees>37.7749290</LatitudeDegrees>'));
      expect(tcx, contains('<Value>142</Value>'));

      // Validate XML structure
      final doc = XmlDocument.parse(tcx);
      expect(doc.findAllElements('Trackpoint').length, 2);
    });

    test('FitGenerator produces valid binary FIT file with signature', () {
      final fitBytes = FitGenerator.generate(mockActivity);
      expect(fitBytes.length, greaterThan(14));

      // Header size is 14 bytes
      expect(fitBytes[0], 14);
      // '.FIT' signature at offset 8..11
      expect(String.fromCharCodes(fitBytes.sublist(8, 12)), '.FIT');
    });
  });

  group('Archive and Local Backup Tests', () {
    test('HuaweiArchiveParser parses raw JSON and ZIP archives', () {
      final sampleJson = '[{"recordId":"123","sportType":283,"startTime":1693849200000,"endTime":1693851000000,"totalDistance":5000.0,"pointList":[{"lat":37.77,"lon":-122.41,"t":1693849200000}]}]';
      final parsed = HuaweiArchiveParser.parseBytes(Uint8List.fromList(sampleJson.codeUnits), fileName: 'data.json');
      expect(parsed.length, 1);
      expect(parsed.first.distanceKm, 5.0);
    });

    test('Huawei Privacy Center JSON format with unquoted numbers and attribute string telemetry', () {
      const huaweiRawJson = '''
      [
        {
          "recordId": "huawei_test_1",
          "sportType": 4,
          "startTime": 1615946404000,
          "endTime": 1615948767000,
          "totalTime": 2363000,
          "totalDistance": 5280,
          "totalCalories": 342000,
          "partTimeMap": {1.0: 461.0, 2.0: 931.0},
          "attribute": "HW_EXT_TRACK_DETAIL@istp=lbs;k=0;lat=19.3707;lon=-99.1552;alt=0.0;t=1.615946456E9;\\ntp=lbs;k=1;lat=19.3712;lon=-99.1558;alt=0.0;t=1.615946462E9;\\ntp=h-r;k=1615946460000;v=145;\\ntp=s-r;k=1615946460000;v=168;\\ntp=alti;k=1615946460000;v=2264.0;\\n&&HW_EXT_TRACK_SIMPLIFY@is{\\"avgHeartRate\\":155,\\"maxHeartRate\\":170,\\"avgStepRate\\":162,\\"creepingWave\\":166.0,\\"mTotalDescent\\":93.0}"
        }
      ]
      ''';

      final activities = MotionPathParser.parseJsonContent(huaweiRawJson, sourceFileName: 'motion_test.json');
      expect(activities.length, 1);
      final act = activities.first;
      expect(act.sportType, ActivityType.outdoorRunning);
      expect(act.distanceKm, closeTo(5.28, 0.01));
      expect(act.trackPoints.length, 2);
      expect(act.avgHeartRate, 155);
      expect(act.maxHeartRate, 170);
      // Elevation from tp=alti should be applied when GPS alt is 0
      expect(act.trackPoints.first.elevation, 2264.0);
      // Heart rate and cadence enrichment
      expect(act.trackPoints.first.heartRate, 145);
      expect(act.trackPoints.first.cadence, 168);
    });
  });
}

