import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../domain/models/workout_activity.dart';
import '../generators/gpx_generator.dart';
import '../generators/tcx_generator.dart';
import '../generators/fit_generator.dart';

enum ExportFormat {
  gpx('GPX (.gpx)', 'gpx', 'application/gpx+xml'),
  tcx('TCX (.tcx)', 'tcx', 'application/vnd.garmin.tcx+xml'),
  fit('FIT (.fit)', 'fit', 'application/octet-stream');

  final String label;
  final String extension;
  final String mimeType;

  const ExportFormat(this.label, this.extension, this.mimeType);
}

class ExportService {
  /// Converts and saves a single workout to temporary/app storage, returning the [File].
  static Future<File> generateExportFile(WorkoutActivity activity, ExportFormat format) async {
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(activity.startTime);
    final sportStr = activity.sportType.name;
    final sanitizedFileName = '${sportStr}_$dateStr.${format.extension}';
    final targetPath = '${tempDir.path}/$sanitizedFileName';

    final file = File(targetPath);

    switch (format) {
      case ExportFormat.gpx:
        final gpxString = GpxGenerator.generate(activity);
        await file.writeAsString(gpxString);
        break;
      case ExportFormat.tcx:
        final tcxString = TcxGenerator.generate(activity);
        await file.writeAsString(tcxString);
        break;
      case ExportFormat.fit:
        final fitBytes = FitGenerator.generate(activity);
        await file.writeAsBytes(fitBytes);
        break;
    }

    return file;
  }

  /// Exports and triggers the system share sheet for a single workout
  static Future<void> shareWorkout(WorkoutActivity activity, ExportFormat format) async {
    final file = await generateExportFile(activity, format);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: format.mimeType)],
      subject: '${activity.title} (${format.label})',
      text: 'Exported from Huawei Health via Huawei Exporter',
    );
  }

  /// Batch exports multiple workouts and triggers system share sheet with all generated files
  static Future<void> batchShareWorkouts(List<WorkoutActivity> activities, ExportFormat format) async {
    final List<XFile> filesToShare = [];

    for (final activity in activities) {
      final file = await generateExportFile(activity, format);
      filesToShare.add(XFile(file.path, mimeType: format.mimeType));
    }

    if (filesToShare.isNotEmpty) {
      await Share.shareXFiles(
        filesToShare,
        subject: 'Batch Huawei Health Export (${filesToShare.length} activities - ${format.label})',
      );
    }
  }
}
