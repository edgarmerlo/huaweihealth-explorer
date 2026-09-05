import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../domain/models/workout_activity.dart';
import 'motion_path_parser.dart';

class HuaweiArchiveParser {
  /// Parses a file path (either a .zip archive or a direct .json file)
  static Future<List<WorkoutActivity>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist at $filePath');
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last.toLowerCase();

    if (fileName.endsWith('.zip')) {
      return parseZipBytes(bytes, archiveName: fileName);
    } else if (fileName.endsWith('.json')) {
      final jsonString = utf8.decode(bytes);
      return MotionPathParser.parseJsonContent(jsonString, sourceFileName: fileName);
    } else {
      // Try to parse as zip first, fallback to JSON
      try {
        return parseZipBytes(bytes, archiveName: fileName);
      } catch (_) {
        final jsonString = utf8.decode(bytes);
        return MotionPathParser.parseJsonContent(jsonString, sourceFileName: fileName);
      }
    }
  }

  /// Parses in-memory ZIP bytes
  static List<WorkoutActivity> parseZipBytes(Uint8List bytes, {String? archiveName}) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<WorkoutActivity> allActivities = [];

    for (final file in archive.files) {
      if (file.isFile) {
        final name = file.name.toLowerCase();
        // Look for motion path detail files or JSON files containing workout data
        if (name.endsWith('.json') && 
            (name.contains('motion') || name.contains('path') || name.contains('detail') || name.contains('track') || name.contains('sport'))) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final activities = MotionPathParser.parseJsonContent(content, sourceFileName: file.name);
            allActivities.addAll(activities);
          } catch (_) {
            // Ignore corrupted inner files and continue
          }
        }
      }
    }

    // If no specific motion files were found, try any JSON file in the archive
    if (allActivities.isEmpty) {
      for (final file in archive.files) {
        if (file.isFile && file.name.toLowerCase().endsWith('.json')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final activities = MotionPathParser.parseJsonContent(content, sourceFileName: file.name);
            allActivities.addAll(activities);
          } catch (_) {}
        }
      }
    }

    // Deduplicate activities by ID / timestamp
    final Map<String, WorkoutActivity> uniqueMap = {};
    for (final act in allActivities) {
      final key = '${act.sportType}_${act.startTime.millisecondsSinceEpoch}';
      if (!uniqueMap.containsKey(key) || act.trackPoints.length > uniqueMap[key]!.trackPoints.length) {
        uniqueMap[key] = act;
      }
    }

    final result = uniqueMap.values.toList();
    result.sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }
}
