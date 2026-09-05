import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/track_point.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/models/sync_record.dart';
import '../../data/parsers/motion_path_parser.dart';
import '../../data/parsers/huawei_archive_parser.dart';
import '../../data/services/export_service.dart';
import '../../data/services/sync_storage_service.dart';
import '../../data/services/strava_service.dart';

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

  /// Opens the system file picker to select a Huawei ZIP or JSON export file
  Future<bool> pickAndImportFile() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final filePath = result.files.first.path!;
      _lastLoadedFileName = result.files.first.name;

      final parsed = await HuaweiArchiveParser.parseFile(filePath);
      
      if (parsed.isEmpty) {
        _errorMessage = 'No workout records found in "${result.files.first.name}". Make sure the ZIP contains "motion path detail data.json".';
      } else {
        _activities = parsed;
        _selectedIds.clear();
      }

      _isLoading = false;
      notifyListeners();
      return parsed.isNotEmpty;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error reading file: ${e.toString()}';
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
      _syncProgressValue = (i + 1) / toSync.length;
      _syncProgressMessage = 'Uploading ${i + 1}/${toSync.length}: ${activity.title}';
      notifyListeners();

      try {
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

  /// Loads mock demo dataset for testing UI without needing a real device file
  void loadSampleData() {
    final now = DateTime.now();
    _activities = [
      WorkoutActivity(
        id: 'huawei_${now.subtract(const Duration(days: 1, hours: 2)).millisecondsSinceEpoch}',
        title: 'Outdoor Run - Morning Intervals',
        sportType: ActivityType.outdoorRunning,
        startTime: now.subtract(const Duration(days: 1, hours: 2)),
        endTime: now.subtract(const Duration(days: 1, hours: 1, minutes: 20)),
        totalDurationSeconds: 2400,
        totalDistanceMeters: 7500.0,
        totalCalories: 520,
        avgHeartRate: 156,
        maxHeartRate: 178,
        totalAscentMeters: 65.0,
        totalDescentMeters: 60.0,
        trackPoints: _generateSampleRoute(
          startLat: 37.7749,
          startLon: -122.4194,
          count: 40,
          startTime: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ),
      WorkoutActivity(
        id: 'huawei_${now.subtract(const Duration(days: 3, hours: 4)).millisecondsSinceEpoch}',
        title: 'Outdoor Cycling - Weekend Loop',
        sportType: ActivityType.outdoorCycling,
        startTime: now.subtract(const Duration(days: 3, hours: 4)),
        endTime: now.subtract(const Duration(days: 3, hours: 2)),
        totalDurationSeconds: 7200,
        totalDistanceMeters: 38200.0,
        totalCalories: 1150,
        avgHeartRate: 142,
        maxHeartRate: 168,
        totalAscentMeters: 320.0,
        totalDescentMeters: 315.0,
        trackPoints: _generateSampleRoute(
          startLat: 37.7833,
          startLon: -122.4167,
          count: 60,
          startTime: now.subtract(const Duration(days: 3, hours: 4)),
        ),
      ),
      WorkoutActivity(
        id: 'huawei_${now.subtract(const Duration(days: 4, hours: 1)).millisecondsSinceEpoch}',
        title: 'Walking - Evening Walk',
        sportType: ActivityType.walking,
        startTime: now.subtract(const Duration(days: 4, hours: 1)),
        endTime: now.subtract(const Duration(days: 4)),
        totalDurationSeconds: 3600,
        totalDistanceMeters: 4800.0,
        totalCalories: 230,
        avgHeartRate: 108,
        maxHeartRate: 125,
        totalAscentMeters: 25.0,
        totalDescentMeters: 20.0,
        trackPoints: _generateSampleRoute(
          startLat: 37.7690,
          startLon: -122.4467,
          count: 30,
          startTime: now.subtract(const Duration(days: 4, hours: 1)),
        ),
      ),
    ];
    _selectedIds.clear();
    _errorMessage = null;
    _lastLoadedFileName = 'Sample Huawei Demo Data';
    notifyListeners();
  }

  static List<TrackPoint> _generateSampleRoute({
    required double startLat,
    required double startLon,
    required int count,
    required DateTime startTime,
  }) {
    final List<dynamic> pts = [];
    double lat = startLat;
    double lon = startLon;
    double alt = 50.0;

    for (int i = 0; i < count; i++) {
      lat += (i % 2 == 0 ? 0.0012 : -0.0004);
      lon += (i % 3 == 0 ? 0.0015 : 0.0008);
      alt += (i % 5 == 0 ? 2.5 : -1.0);
      final t = startTime.add(Duration(seconds: i * 60));
      pts.add({
        'lat': lat,
        'lon': lon,
        'alt': alt,
        't': t.millisecondsSinceEpoch,
        'hr': 140 + (i % 25),
        'cadence': 160 + (i % 15),
      });
    }

    return MotionPathParser.parseJsonContent([
      {
        'sportType': 283,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': startTime.add(Duration(seconds: count * 60)).millisecondsSinceEpoch,
        'pointList': pts,
        'totalDistance': 5000.0,
        'totalCalories': 300,
      }
    ]).first.trackPoints;
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
