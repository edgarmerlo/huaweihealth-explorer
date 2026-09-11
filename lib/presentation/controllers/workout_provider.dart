import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/models/sync_record.dart';
import '../../data/parsers/huawei_archive_parser.dart';
import '../../data/services/export_service.dart';
import '../../data/services/sync_storage_service.dart';
import '../../data/services/strava_service.dart';
import '../../data/services/native_zip_service.dart';

enum SyncFilterMode {
  all('All'),
  newOnly('New (Unsynced)'),
  syncedOnly('Synced');

  final String label;
  const SyncFilterMode(this.label);
}

class WorkoutProvider extends ChangeNotifier {
  final SyncStorageService _syncStorage = SyncStorageService.instance;
  final StravaService _stravaService = StravaService.instance;

  List<WorkoutActivity> _activities = [];
  final Set<String> _selectedIds = {};
  ActivityType? _selectedSportFilter;
  SyncFilterMode _syncFilter = SyncFilterMode.all;
  bool _isLoading = false;
  String? _loadingMessage;
  bool _isSyncing = false;
  String? _syncProgressMessage;
  double _syncProgressValue = 0.0;
  String? _errorMessage;
  String? _lastLoadedFileName;

  WorkoutProvider() {
    _initServices();
  }

  Future<void> _initServices() async {
    await _syncStorage.init();
    await _stravaService.init();
    notifyListeners();
  }

  List<WorkoutActivity> get activities => _activities;
  Set<String> get selectedIds => _selectedIds;
  ActivityType? get selectedSportFilter => _selectedSportFilter;
  SyncFilterMode get syncFilter => _syncFilter;
  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;
  bool get isSyncing => _isSyncing;
  String? get syncProgressMessage => _syncProgressMessage;
  double get syncProgressValue => _syncProgressValue;
  String? get errorMessage => _errorMessage;
  String? get lastLoadedFileName => _lastLoadedFileName;
  bool get isStravaConnected => _stravaService.isConnected;
  String? get stravaAthleteName => _stravaService.credentials?.athleteName;

  void refresh() {
    notifyListeners();
  }

  // Sync status helpers
  SyncStatus getSyncStatus(WorkoutActivity activity) => _syncStorage.getStatus(activity);
  bool isActivitySynced(WorkoutActivity activity) => _syncStorage.isSynced(activity);
  bool isActivityModified(WorkoutActivity activity) => _syncStorage.isModified(activity);
  SyncRecord? getSyncRecord(String activityId) => _syncStorage.getRecord(activityId);

  List<WorkoutActivity> get unsyncedActivities => 
      _activities.where((a) => !isActivitySynced(a) || isActivityModified(a)).toList();

  List<WorkoutActivity> get syncedActivities => 
      _activities.where((a) => isActivitySynced(a) && !isActivityModified(a)).toList();

  List<WorkoutActivity> get filteredActivities {
    return _activities.where((a) {
      // 1. Sport filter
      if (_selectedSportFilter != null && a.sportType != _selectedSportFilter) {
        return false;
      }
      // 2. Sync filter
      if (_syncFilter == SyncFilterMode.newOnly) {
        return !isActivitySynced(a) || isActivityModified(a);
      } else if (_syncFilter == SyncFilterMode.syncedOnly) {
        return isActivitySynced(a) && !isActivityModified(a);
      }
      return true;
    }).toList();
  }

  int get totalActivities => _activities.length;
  int get unsyncedCount => unsyncedActivities.length;
  int get syncedCount => syncedActivities.length;
  double get totalDistanceKm => _activities.fold(0.0, (sum, a) => sum + a.distanceKm);
  int get totalDurationMinutes => _activities.fold(0, (sum, a) => sum + (a.totalDurationSeconds ~/ 60));

  bool isSelected(String id) => _selectedIds.contains(id);

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds.clear();
    for (final a in filteredActivities) {
      _selectedIds.add(a.permanentId);
    }
    notifyListeners();
  }

  void selectAllUnsynced() {
    _selectedIds.clear();
    for (final a in unsyncedActivities) {
      _selectedIds.add(a.permanentId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void setSportFilter(ActivityType? filter) {
    _selectedSportFilter = filter;
    notifyListeners();
  }

  void setSyncFilter(SyncFilterMode filter) {
    _syncFilter = filter;
    notifyListeners();
  }

  /// Opens the system file picker to select a Huawei Privacy Export ZIP file
  Future<bool> pickAndImportFile({
    Future<String?> Function(String fileName, {bool isRetry})? onPasswordPrompt,
  }) async {
    try {
      _isLoading = true;
      _loadingMessage = 'Selecting Huawei ZIP file...';
      _errorMessage = null;
      notifyListeners();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        _isLoading = false;
        _loadingMessage = null;
        notifyListeners();
        return false;
      }

      final filePath = result.files.first.path!;
      final fileName = result.files.first.name;
      _lastLoadedFileName = fileName;

      // Check if ZIP archive is encrypted with password
      final isEncrypted = await NativeZipService.isEncrypted(filePath);

      final tempBase = await getTemporaryDirectory();
      final extractDir = Directory('${tempBase.path}/huawei_unzip_${DateTime.now().millisecondsSinceEpoch}');

      if (isEncrypted) {
        String? password;
        bool isRetry = false;

        while (true) {
          _isLoading = false;
          _loadingMessage = null;
          notifyListeners();

          if (onPasswordPrompt != null) {
            password = await onPasswordPrompt(fileName, isRetry: isRetry);
            if (password == null) {
              // User cancelled password prompt
              _isLoading = false;
              _loadingMessage = null;
              notifyListeners();
              return false;
            }
          }

          _isLoading = true;
          _loadingMessage = 'Unlocking and unzipping Huawei archive...';
          notifyListeners();

          if (await extractDir.exists()) {
            try { await extractDir.delete(recursive: true); } catch (_) {}
          }
          await extractDir.create(recursive: true);

          final res = await NativeZipService.extractZip(
            zipPath: filePath,
            destinationDir: extractDir.path,
            password: password,
          );

          if (res.success) {
            _loadingMessage = 'Parsing workout routes and telemetry...';
            notifyListeners();

            final parsed = await HuaweiArchiveParser.parseDirectory(extractDir);
            try { await extractDir.delete(recursive: true); } catch (_) {}

            if (parsed.isEmpty) {
              _errorMessage = 'No workout tracks found in "$fileName". Make sure this is your Huawei Privacy Center export ZIP.';
              _isLoading = false;
              _loadingMessage = null;
              notifyListeners();
              return false;
            }

            _activities = parsed;
            _selectedIds.clear();
            _isLoading = false;
            _loadingMessage = null;
            notifyListeners();
            return true;
          } else if (res.isWrongPassword) {
            try { await extractDir.delete(recursive: true); } catch (_) {}
            isRetry = true;
            continue;
          } else {
            try { await extractDir.delete(recursive: true); } catch (_) {}
            _errorMessage = res.errorMessage ?? 'Failed to extract ZIP archive';
            _isLoading = false;
            _loadingMessage = null;
            notifyListeners();
            return false;
          }
        }
      } else {
        // Not encrypted: extract and parse
        _isLoading = true;
        _loadingMessage = 'Extracting Huawei archive...';
        notifyListeners();

        await extractDir.create(recursive: true);
        final res = await NativeZipService.extractZip(
          zipPath: filePath,
          destinationDir: extractDir.path,
        );

        List<WorkoutActivity> parsed = [];
        if (res.success) {
          _loadingMessage = 'Parsing workout routes and telemetry...';
          notifyListeners();
          parsed = await HuaweiArchiveParser.parseDirectory(extractDir);
          try { await extractDir.delete(recursive: true); } catch (_) {}
        } else {
          try { await extractDir.delete(recursive: true); } catch (_) {}
          parsed = await HuaweiArchiveParser.parseFile(filePath);
        }

        if (parsed.isEmpty) {
          _errorMessage = 'No workout records found in "$fileName". Make sure this is the Huawei Privacy Center export ZIP.';
        } else {
          _activities = parsed;
          _selectedIds.clear();
        }

        _isLoading = false;
        _loadingMessage = null;
        notifyListeners();
        return parsed.isNotEmpty;
      }
    } catch (e) {
      _isLoading = false;
      _loadingMessage = null;
      _errorMessage = 'Error reading ZIP archive: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Syncs only new / modified activities directly to Strava
  Future<Map<String, int>> syncNewToStrava({
    List<WorkoutActivity>? targetActivities,
  }) async {
    if (!_stravaService.isConnected) {
      throw Exception('Strava is not connected. Please connect your Strava account first.');
    }

    final toSync = targetActivities ?? unsyncedActivities;
    if (toSync.isEmpty) {
      return {'success': 0, 'duplicates': 0, 'failed': 0};
    }

    _isSyncing = true;
    _syncProgressValue = 0.0;
    _syncProgressMessage = 'Starting sync with Strava...';
    notifyListeners();

    int successCount = 0;
    int duplicateCount = 0;
    int failedCount = 0;

    for (int i = 0; i < toSync.length; i++) {
      final activity = toSync[i];
      final isModifiedWorkout = isActivityModified(activity);
      final existingRecord = _syncStorage.getRecord(activity.permanentId);

      _syncProgressValue = (i + 1) / toSync.length;
      _syncProgressMessage = isModifiedWorkout
          ? 'Updating ${i + 1}/${toSync.length}: ${activity.title} (calibrated/edited)'
          : 'Uploading ${i + 1}/${toSync.length}: ${activity.title}';
      notifyListeners();

      try {
        // If modified workout was previously on Strava, remove old version so Strava accepts update
        if (isModifiedWorkout && existingRecord?.stravaActivityId != null) {
          await _stravaService.deleteActivity(existingRecord!.stravaActivityId!);
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final result = await _stravaService.uploadActivity(activity);

        if (result.success) {
          if (result.isDuplicate) {
            duplicateCount++;
            await _syncStorage.markDuplicate(
              activity,
              stravaActivityId: result.stravaActivityId,
            );
          } else {
            successCount++;
            await _syncStorage.markSynced(
              activity,
              stravaActivityId: result.stravaActivityId,
              uploadId: result.uploadId,
            );
          }
        } else {
          failedCount++;
          debugPrint('Upload failed for ${activity.title}: ${result.errorMessage}');
        }
      } catch (e) {
        failedCount++;
        debugPrint('Upload exception for ${activity.title}: $e');
      }

      // Small pause between bulk uploads to respect Strava rate limits
      if (i < toSync.length - 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    _isSyncing = false;
    _syncProgressMessage = null;
    notifyListeners();

    return {
      'success': successCount,
      'duplicates': duplicateCount,
      'failed': failedCount,
    };
  }

  /// Re-verifies if an activity exists on Strava (e.g. if user deleted it on Strava)
  Future<bool> recheckActivityOnStrava(WorkoutActivity activity) async {
    final record = _syncStorage.getRecord(activity.permanentId);
    if (record == null || record.stravaActivityId == null) return false;

    final exists = await _stravaService.checkActivityExists(record.stravaActivityId!);
    if (!exists) {
      // User deleted activity on Strava, reset status to unsynced
      await _syncStorage.markUnsynced(activity.permanentId);
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> exportSingle(WorkoutActivity activity, ExportFormat format) async {
    await ExportService.shareWorkout(activity, format);
  }

  Future<void> exportBatch(ExportFormat format) async {
    final targets = _selectedIds.isEmpty
        ? filteredActivities
        : _activities.where((a) => _selectedIds.contains(a.permanentId)).toList();

    if (targets.isEmpty) return;
    await ExportService.batchShareWorkouts(targets, format);
  }
}
