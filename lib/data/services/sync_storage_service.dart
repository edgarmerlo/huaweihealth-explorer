import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sync_record.dart';
import '../../domain/models/workout_activity.dart';

class SyncStorageService {
  static const String _ledgerFileName = 'huawei_sync_ledger.json';
  static SyncStorageService? _instance;
  final Map<String, SyncRecord> _records = {};
  bool _isInitialized = false;

  SyncStorageService._();

  static SyncStorageService get instance {
    _instance ??= SyncStorageService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getLedgerFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> jsonMap = jsonDecode(content);
          _records.clear();
          jsonMap.forEach((key, val) {
            if (val is Map<String, dynamic>) {
              _records[key] = SyncRecord.fromJson(val);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error reading sync ledger: $e');
    } finally {
      _isInitialized = true;
    }
  }

  SyncStatus getStatus(WorkoutActivity activity) {
    final record = _records[activity.permanentId];
    if (record == null) {
      return SyncStatus.unsynced;
    }

    // Check if activity content was edited/recalibrated in Huawei Health
    if (record.contentHash != activity.contentHash) {
      return SyncStatus.modified;
    }

    return record.status;
  }

  SyncRecord? getRecord(String activityId) => _records[activityId];

  bool isSynced(WorkoutActivity activity) {
    final status = getStatus(activity);
    return status == SyncStatus.synced || status == SyncStatus.duplicate;
  }

  bool isModified(WorkoutActivity activity) {
    return getStatus(activity) == SyncStatus.modified;
  }

  Future<void> markSynced(
    WorkoutActivity activity, {
    int? stravaActivityId,
    String? uploadId,
  }) async {
    final now = DateTime.now();
    _records[activity.permanentId] = SyncRecord(
      activityId: activity.permanentId,
      contentHash: activity.contentHash,
      status: SyncStatus.synced,
      stravaActivityId: stravaActivityId ?? _records[activity.permanentId]?.stravaActivityId,
      stravaUploadId: uploadId ?? _records[activity.permanentId]?.stravaUploadId,
      lastUploadedAt: now,
      lastCheckedAt: now,
    );
    await _saveToDisk();
  }

  Future<void> markDuplicate(
    WorkoutActivity activity, {
    int? stravaActivityId,
  }) async {
    final now = DateTime.now();
    _records[activity.permanentId] = SyncRecord(
      activityId: activity.permanentId,
      contentHash: activity.contentHash,
      status: SyncStatus.duplicate,
      stravaActivityId: stravaActivityId ?? _records[activity.permanentId]?.stravaActivityId,
      lastUploadedAt: _records[activity.permanentId]?.lastUploadedAt ?? now,
      lastCheckedAt: now,
    );
    await _saveToDisk();
  }

  Future<void> markUnsynced(String activityId) async {
    _records.remove(activityId);
    await _saveToDisk();
  }

  Future<void> updateStravaActivityId(String activityId, int stravaActivityId) async {
    final record = _records[activityId];
    if (record != null) {
      _records[activityId] = record.copyWith(
        stravaActivityId: stravaActivityId,
        lastCheckedAt: DateTime.now(),
      );
      await _saveToDisk();
    }
  }

  Map<String, SyncRecord> getAllRecords() => Map.unmodifiable(_records);

  Future<void> clearLedger() async {
    _records.clear();
    final file = await _getLedgerFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getLedgerFile();
      final Map<String, dynamic> jsonMap = {};
      _records.forEach((key, record) {
        jsonMap[key] = record.toJson();
      });
      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      debugPrint('Error saving sync ledger: $e');
    }
  }

  Future<File> _getLedgerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_ledgerFileName');
  }
}
