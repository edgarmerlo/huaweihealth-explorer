enum ActivityType {
  outdoorRunning,
  indoorRunning,
  outdoorCycling,
  indoorCycling,
  walking,
  hiking,
  trailRunning,
  swimming,
  crossTrainer,
  other;

  String get displayName {
    switch (this) {
      case ActivityType.outdoorRunning:
        return 'Outdoor Run';
      case ActivityType.indoorRunning:
        return 'Treadmill / Indoor Run';
      case ActivityType.outdoorCycling:
        return 'Outdoor Cycling';
      case ActivityType.indoorCycling:
        return 'Indoor Cycling';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.hiking:
        return 'Hiking';
      case ActivityType.trailRunning:
        return 'Trail Run';
      case ActivityType.swimming:
        return 'Swimming';
      case ActivityType.crossTrainer:
        return 'Elliptical';
      case ActivityType.other:
        return 'Workout';
    }
  }

  String get tcxSportName {
    switch (this) {
      case ActivityType.outdoorRunning:
      case ActivityType.indoorRunning:
      case ActivityType.trailRunning:
        return 'Running';
      case ActivityType.outdoorCycling:
      case ActivityType.indoorCycling:
        return 'Biking';
      default:
        return 'Other';
    }
  }

  String get gpxActivityType {
    switch (this) {
      case ActivityType.outdoorRunning:
      case ActivityType.indoorRunning:
      case ActivityType.trailRunning:
        return 'running';
      case ActivityType.outdoorCycling:
      case ActivityType.indoorCycling:
        return 'cycling';
      case ActivityType.walking:
        return 'walking';
      case ActivityType.hiking:
        return 'hiking';
      case ActivityType.swimming:
        return 'swimming';
      default:
        return 'other';
    }
  }

  static ActivityType fromHuaweiCode(dynamic code) {
    if (code == null) return ActivityType.other;
    final intCode = code is int ? code : int.tryParse(code.toString()) ?? -1;

    switch (intCode) {
      case 1:
      case 283:
        return ActivityType.outdoorRunning;
      case 2:
      case 284:
        return ActivityType.indoorRunning;
      case 3:
      case 281:
      case 282:
        return ActivityType.walking;
      case 4:
      case 285:
        return ActivityType.outdoorCycling;
      case 5:
      case 288:
        return ActivityType.indoorCycling;
      case 6:
      case 286:
        return ActivityType.hiking;
      case 7:
      case 287:
        return ActivityType.trailRunning;
      case 8:
      case 289:
      case 290:
        return ActivityType.swimming;
      case 9:
        return ActivityType.crossTrainer;
      default:
        return ActivityType.other;
    }
  }
}
