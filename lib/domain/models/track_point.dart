class TrackPoint {
  final double latitude;
  final double longitude;
  final double? elevation;
  final DateTime timestamp;
  final int? heartRate;
  final int? cadence;
  final double? speed;
  final double? distanceMeters;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.elevation,
    this.heartRate,
    this.cadence,
    this.speed,
    this.distanceMeters,
  });

  TrackPoint copyWith({
    double? latitude,
    double? longitude,
    double? elevation,
    DateTime? timestamp,
    int? heartRate,
    int? cadence,
    double? speed,
    double? distanceMeters,
  }) {
    return TrackPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      elevation: elevation ?? this.elevation,
      heartRate: heartRate ?? this.heartRate,
      cadence: cadence ?? this.cadence,
      speed: speed ?? this.speed,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'elevation': elevation,
    'timestamp': timestamp.toIso8601String(),
    'heartRate': heartRate,
    'cadence': cadence,
    'speed': speed,
    'distanceMeters': distanceMeters,
  };
}
