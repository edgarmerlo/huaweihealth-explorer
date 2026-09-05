import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/models/activity_type.dart';
import '../../domain/models/track_point.dart';
import '../../domain/models/workout_activity.dart';
import '../../data/parsers/motion_path_parser.dart';
import '../../data/parsers/huawei_archive_parser.dart';
import '../../data/services/export_service.dart';

class WorkoutProvider extends ChangeNotifier {
  List<WorkoutActivity> _activities = [];
  final Set<String> _selectedIds = {};
  ActivityType? _selectedFilter;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastLoadedFileName;

  List<WorkoutActivity> get activities => _activities;
  Set<String> get selectedIds => _selectedIds;
  ActivityType? get selectedFilter => _selectedFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastLoadedFileName => _lastLoadedFileName;

  List<WorkoutActivity> get filteredActivities {
    if (_selectedFilter == null) return _activities;
    return _activities.where((a) => a.sportType == _selectedFilter).toList();
  }

  int get totalActivities => _activities.length;
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
      _selectedIds.add(a.id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  void setFilter(ActivityType? filter) {
    _selectedFilter = filter;
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

  /// Loads mock demo dataset for testing UI without needing a real device file
  void loadSampleData() {
    final now = DateTime.now();
    _activities = [
      WorkoutActivity(
        id: 'sample_run_1',
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
        id: 'sample_cycle_1',
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
        id: 'sample_walk_1',
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
    // Generates sample trackpoints in a loop
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
        : _activities.where((a) => _selectedIds.contains(a.id)).toList();

    if (targets.isEmpty) return;
    await ExportService.batchShareWorkouts(targets, format);
  }
}
