import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../domain/models/workout_activity.dart';
import 'motion_path_parser.dart';

class HuaweiArchiveParser {
  /// Parses an uncompressed directory recursively, finding and parsing all workout JSON files
  static Future<List<WorkoutActivity>> parseDirectory(
    Directory dir, {
    void Function(int processedFiles, int totalFiles)? onProgress,
  }) async {
    final List<WorkoutActivity> allActivities = [];
    if (!await dir.exists()) {
      return allActivities;
    }

    final entities = dir.listSync(recursive: true);
    final jsonFiles = entities.whereType<File>().where((f) {
      final name = f.uri.pathSegments.last.toLowerCase();
      return name.endsWith('.json') && (
        name.contains('motion path') ||
        name.contains('motion_path') ||
        name.contains('sport_data') ||
        name.contains('track') ||
        name.contains('detail')
      );
    }).toList();

    final targets = jsonFiles.isNotEmpty 
        ? jsonFiles 
        : entities.whereType<File>().where((f) => f.path.toLowerCase().endsWith('.json')).toList();

    for (int i = 0; i < targets.length; i++) {
      final file = targets[i];
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty && content.trim() != '[]') {
          final parsed = MotionPathParser.parseJsonContent(
            content,
            sourceFileName: file.uri.pathSegments.last,
          );
          allActivities.addAll(parsed);
        }
      } catch (_) {
        // Skip unparseable files
      }
      onProgress?.call(i + 1, targets.length);
    }

    // Deduplicate activities by sportType and timestamp
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

  /// Parses a file path (either a .zip, .tar, .tar.gz, .tgz, or .json file)
  static Future<List<WorkoutActivity>> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist at $filePath');
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last.toLowerCase();

    return parseBytes(bytes, fileName: fileName);
  }

  /// Parses in-memory archive or JSON bytes
  static List<WorkoutActivity> parseBytes(Uint8List bytes, {String? fileName}) {
    final lowerName = fileName?.toLowerCase() ?? '';

    // Direct JSON file
    if (lowerName.endsWith('.json')) {
      final jsonString = utf8.decode(bytes, allowMalformed: true);
      return MotionPathParser.parseJsonContent(jsonString, sourceFileName: fileName);
    }

    final List<WorkoutActivity> allActivities = [];

    // 1. Try ZIP decoder
    try {
      final zipArchive = ZipDecoder().decodeBytes(bytes, verify: false);
      final zipActivities = _extractFromArchive(zipArchive);
      allActivities.addAll(zipActivities);
    } catch (_) {
      // Not a ZIP archive
    }

    // 2. Try TAR / TAR.GZ decoder (Huawei Local Backup / HiSuite format)
    if (allActivities.isEmpty) {
      try {
        Uint8List tarBytes = bytes;
        // Check for GZip header magic bytes (0x1F, 0x8B)
        if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
          tarBytes = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
        }

        final tarArchive = TarDecoder().decodeBytes(tarBytes);
        final tarActivities = _extractFromArchive(tarArchive);
        allActivities.addAll(tarActivities);
      } catch (_) {
        // Not a TAR archive
      }
    }

    // 3. Fallback: try raw JSON string directly in case file has non-standard extension
    if (allActivities.isEmpty) {
      try {
        final content = utf8.decode(bytes, allowMalformed: true);
        if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
          final directActivities = MotionPathParser.parseJsonContent(content, sourceFileName: fileName);
          allActivities.addAll(directActivities);
        }
      } catch (_) {}
    }

    // Deduplicate activities by sportType and timestamp
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

  /// Extracts workout records from an Archive (works for both Zip and Tar)
  static List<WorkoutActivity> _extractFromArchive(Archive archive) {
    final List<WorkoutActivity> activities = [];

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.toLowerCase();

      // Check for nested .tar, .tar.gz, or .zip inside the backup
      if (name.endsWith('.tar') || name.endsWith('.tar.gz') || name.endsWith('.tgz') || name.endsWith('.zip')) {
        try {
          final nestedBytes = Uint8List.fromList(file.content as List<int>);
          final nested = parseBytes(nestedBytes, fileName: file.name);
          activities.addAll(nested);
          continue;
        } catch (_) {}
      }

      // Check for motion path JSON files or files containing motion / health workout data
      final isMotionFile = name.endsWith('.json') || 
                           name.contains('motion_path') || 
                           name.contains('motionpath') || 
                           name.contains('sport_data') ||
                           name.contains('track');

      if (isMotionFile) {
        try {
          final content = utf8.decode(file.content as List<int>, allowMalformed: true);
          final parsed = MotionPathParser.parseJsonContent(content, sourceFileName: file.name);
          activities.addAll(parsed);
        } catch (_) {}
      }
    }

    // Fallback: If no motion-specific files found, inspect all other text/json files in archive
    if (activities.isEmpty) {
      for (final file in archive.files) {
        if (!file.isFile) continue;
        try {
          final content = utf8.decode(file.content as List<int>, allowMalformed: true);
          if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
            final parsed = MotionPathParser.parseJsonContent(content, sourceFileName: file.name);
            activities.addAll(parsed);
          }
        } catch (_) {}
      }
    }

    return activities;
  }
}
