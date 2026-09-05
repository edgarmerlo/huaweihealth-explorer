enum SyncStatus {
  unsynced,
  synced,
  duplicate,
  modified;

  String get label {
    switch (this) {
      case SyncStatus.unsynced:
        return 'New';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.duplicate:
        return 'Duplicate';
      case SyncStatus.modified:
        return 'Modified';
    }
  }
}

class SyncRecord {
  final String activityId;
  final String contentHash;
  final SyncStatus status;
  final int? stravaActivityId;
  final String? stravaUploadId;
  final DateTime? lastUploadedAt;
  final DateTime? lastCheckedAt;

  const SyncRecord({
    required this.activityId,
    required this.contentHash,
    required this.status,
    this.stravaActivityId,
    this.stravaUploadId,
    this.lastUploadedAt,
    this.lastCheckedAt,
  });

  SyncRecord copyWith({
    String? activityId,
    String? contentHash,
    SyncStatus? status,
    int? stravaActivityId,
    String? stravaUploadId,
    DateTime? lastUploadedAt,
    DateTime? lastCheckedAt,
  }) {
    return SyncRecord(
      activityId: activityId ?? this.activityId,
      contentHash: contentHash ?? this.contentHash,
      status: status ?? this.status,
      stravaActivityId: stravaActivityId ?? this.stravaActivityId,
      stravaUploadId: stravaUploadId ?? this.stravaUploadId,
      lastUploadedAt: lastUploadedAt ?? this.lastUploadedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'activityId': activityId,
    'contentHash': contentHash,
    'status': status.name,
    'stravaActivityId': stravaActivityId,
    'stravaUploadId': stravaUploadId,
    'lastUploadedAt': lastUploadedAt?.toIso8601String(),
    'lastCheckedAt': lastCheckedAt?.toIso8601String(),
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    return SyncRecord(
      activityId: json['activityId'] as String,
      contentHash: json['contentHash'] as String? ?? '',
      status: SyncStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SyncStatus.synced,
      ),
      stravaActivityId: json['stravaActivityId'] as int?,
      stravaUploadId: json['stravaUploadId'] as String?,
      lastUploadedAt: json['lastUploadedAt'] != null 
          ? DateTime.tryParse(json['lastUploadedAt'] as String) 
          : null,
      lastCheckedAt: json['lastCheckedAt'] != null 
          ? DateTime.tryParse(json['lastCheckedAt'] as String) 
          : null,
    );
  }
}
