import 'package:flutter_test/flutter_test.dart';
import 'package:huawei_health_export/domain/models/activity_type.dart';
import 'package:huawei_health_export/domain/models/workout_activity.dart';
import 'package:huawei_health_export/data/models/sync_record.dart';
import 'package:huawei_health_export/data/services/sync_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sync & Deduplication Tests', () {
    final activity1 = WorkoutActivity(
      id: 'huawei_1693849200000',
      title: 'Morning 5K Run',
      sportType: ActivityType.outdoorRunning,
      startTime: DateTime.fromMillisecondsSinceEpoch(1693849200000, isUtc: true),
      endTime: DateTime.fromMillisecondsSinceEpoch(1693851000000, isUtc: true),
      totalDurationSeconds: 1800,
      totalDistanceMeters: 5000.0,
      totalCalories: 350,
      avgHeartRate: 155,
      maxHeartRate: 175,
    );

    test('Initial activity is recognized as unsynced (New)', () {
      final syncService = SyncStorageService.instance;
      expect(syncService.getStatus(activity1), SyncStatus.unsynced);
      expect(syncService.isSynced(activity1), isFalse);
    });

    test('Marking activity as synced updates status to synced', () async {
      final syncService = SyncStorageService.instance;
      await syncService.markSynced(activity1, stravaActivityId: 987654321);

      expect(syncService.getStatus(activity1), SyncStatus.synced);
      expect(syncService.isSynced(activity1), isTrue);
      expect(syncService.isModified(activity1), isFalse);
    });

    test('Modifying workout data in Huawei changes contentHash and yields modified status', () {
      final syncService = SyncStorageService.instance;

      // Same permanentId / startTime, but distance was calibrated in Huawei Health (5.0 km -> 5.2 km)
      final modifiedActivity = WorkoutActivity(
        id: 'huawei_1693849200000',
        title: 'Morning 5K Run',
        sportType: ActivityType.outdoorRunning,
        startTime: DateTime.fromMillisecondsSinceEpoch(1693849200000, isUtc: true),
        endTime: DateTime.fromMillisecondsSinceEpoch(1693851000000, isUtc: true),
        totalDurationSeconds: 1800,
        totalDistanceMeters: 5200.0, // Changed
        totalCalories: 370, // Changed
        avgHeartRate: 155,
        maxHeartRate: 175,
      );

      expect(syncService.getStatus(modifiedActivity), SyncStatus.modified);
      expect(syncService.isModified(modifiedActivity), isTrue);
    });

    test('Strava duplicate detection marks activity as duplicate/synced', () async {
      final syncService = SyncStorageService.instance;
      final activity2 = WorkoutActivity(
        id: 'huawei_1693900000000',
        title: 'Evening Cycling',
        sportType: ActivityType.outdoorCycling,
        startTime: DateTime.fromMillisecondsSinceEpoch(1693900000000, isUtc: true),
        endTime: DateTime.fromMillisecondsSinceEpoch(1693903600000, isUtc: true),
        totalDurationSeconds: 3600,
        totalDistanceMeters: 25000.0,
        totalCalories: 600,
      );

      await syncService.markDuplicate(activity2, stravaActivityId: 11223344);
      expect(syncService.getStatus(activity2), SyncStatus.duplicate);
      expect(syncService.isSynced(activity2), isTrue);
    });
  });
}
