class HeartRateSample {
  final DateTime timestamp;
  final int bpm;

  const HeartRateSample({
    required this.timestamp,
    required this.bpm,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'bpm': bpm,
  };
}

class CadenceSample {
  final DateTime timestamp;
  final int rpm;

  const CadenceSample({
    required this.timestamp,
    required this.rpm,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'rpm': rpm,
  };
}
