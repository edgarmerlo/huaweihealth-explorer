import 'dart:typed_data';
import '../../domain/models/activity_type.dart';
import '../../domain/models/workout_activity.dart';

class FitGenerator {
  // FIT Epoch: 1989-12-31 00:00:00 UTC (in seconds since Unix epoch = 631065600)
  static const int _fitEpochOffset = 631065600;

  /// Converts a [WorkoutActivity] into a valid binary FIT file bytes array.
  static Uint8List generate(WorkoutActivity activity) {
    final builder = BytesBuilder();

    // 1. Write File ID Definition & Data Message
    _writeFileIdMessage(builder, activity.startTime);

    // 2. Write Event Start Message
    _writeEventMessage(builder, activity.startTime, eventType: 0); // 0 = start

    // 3. Write Record Definition & Data Messages (Trackpoints)
    if (activity.trackPoints.isNotEmpty) {
      _writeRecordMessages(builder, activity);
    }

    // 4. Write Event Stop Message
    _writeEventMessage(builder, activity.endTime, eventType: 4); // 4 = stop_all / stop

    // 5. Write Lap Message
    _writeLapMessage(builder, activity);

    // 6. Write Session Message
    _writeSessionMessage(builder, activity);

    // 7. Write Activity Message
    _writeActivityMessage(builder, activity);

    final dataBytes = builder.toBytes();
    final dataSize = dataBytes.length;

    // 8. Build 14-byte Header
    final header = ByteData(14);
    header.setUint8(0, 14); // Header size
    header.setUint8(1, 0x20); // Protocol version (2.0)
    header.setUint16(2, 2100, Endian.little); // Profile version
    header.setUint32(4, dataSize, Endian.little); // Data size
    header.setUint8(8, 0x2E); // '.'
    header.setUint8(9, 0x46); // 'F'
    header.setUint8(10, 0x49); // 'I'
    header.setUint8(11, 0x54); // 'T'

    // Compute Header CRC
    final headerCrc = _computeCrc(header.buffer.asUint8List(0, 12));
    header.setUint16(12, headerCrc, Endian.little);

    // Combine Header + Data
    final fullFileBuilder = BytesBuilder();
    fullFileBuilder.add(header.buffer.asUint8List());
    fullFileBuilder.add(dataBytes);

    // Compute File CRC (over Header + Data)
    final fileBytesWithoutCrc = fullFileBuilder.toBytes();
    final fileCrc = _computeCrc(fileBytesWithoutCrc);

    final fileCrcBytes = ByteData(2);
    fileCrcBytes.setUint16(0, fileCrc, Endian.little);
    fullFileBuilder.add(fileCrcBytes.buffer.asUint8List());

    return fullFileBuilder.toBytes();
  }

  static void _writeFileIdMessage(BytesBuilder builder, DateTime timeCreated) {
    // Definition Message for File ID (Global Mesg Num 0)
    // Local mesg 0, has 4 fields: type(0), manufacturer(1), product(2), time_created(4)
    final def = BytesBuilder();
    def.addByte(0x40); // Definition message header, local mesg 0
    def.addByte(0x00); // Reserved
    def.addByte(0x00); // Architecture: 0 = Little Endian
    def.add([0x00, 0x00]); // Global Mesg Num = 0 (File ID)
    def.addByte(4); // 4 fields

    // Field 0: type (enum, 1 byte)
    def.add([0x00, 0x01, 0x00]);
    // Field 1: manufacturer (uint16, 2 bytes)
    def.add([0x01, 0x02, 0x84]);
    // Field 2: product (uint16, 2 bytes)
    def.add([0x02, 0x02, 0x84]);
    // Field 3: time_created (uint32, 4 bytes)
    def.add([0x04, 0x04, 0x86]);

    builder.add(def.toBytes());

    // Data Message for File ID
    final data = ByteData(1 + 2 + 2 + 4 + 1);
    data.setUint8(0, 0x00); // Data message header, local mesg 0
    data.setUint8(1, 4); // Type: 4 = Activity
    data.setUint16(2, 255, Endian.little); // Manufacturer: Development
    data.setUint16(4, 0, Endian.little); // Product: 0
    data.setUint32(6, _toFitTimestamp(timeCreated), Endian.little); // Time created

    builder.add(data.buffer.asUint8List(0, 10));
  }

  static void _writeEventMessage(BytesBuilder builder, DateTime timestamp, {required int eventType}) {
    // Definition Message for Event (Global Mesg Num 21)
    // Local mesg 1: timestamp(253), event(0), event_type(1)
    final def = BytesBuilder();
    def.addByte(0x41); // Definition, local mesg 1
    def.addByte(0x00);
    def.addByte(0x00); // Little endian
    def.add([0x15, 0x00]); // Global Mesg Num = 21 (Event)
    def.addByte(3); // 3 fields

    // Field 0: timestamp (uint32, 4 bytes)
    def.add([0xFD, 0x04, 0x86]);
    // Field 1: event (enum, 1 byte) - 0 = timer
    def.add([0x00, 0x01, 0x00]);
    // Field 2: event_type (enum, 1 byte)
    def.add([0x01, 0x01, 0x00]);

    builder.add(def.toBytes());

    // Data Message
    final data = ByteData(7);
    data.setUint8(0, 0x01); // Data, local mesg 1
    data.setUint32(1, _toFitTimestamp(timestamp), Endian.little);
    data.setUint8(5, 0); // Event: 0 = Timer
    data.setUint8(6, eventType); // Event Type (0 = start, 4 = stop_all)

    builder.add(data.buffer.asUint8List());
  }

  static void _writeRecordMessages(BytesBuilder builder, WorkoutActivity activity) {
    // Definition Message for Record (Global Mesg Num 20)
    // Local mesg 2: timestamp(253), position_lat(0), position_long(1), altitude(2), heart_rate(3), cadence(4), distance(5), speed(6)
    final def = BytesBuilder();
    def.addByte(0x42); // Definition, local mesg 2
    def.addByte(0x00);
    def.addByte(0x00); // Little Endian
    def.add([0x14, 0x00]); // Global Mesg Num = 20 (Record)
    def.addByte(8); // 8 fields

    // Field 0: timestamp (uint32, 4 bytes)
    def.add([0xFD, 0x04, 0x86]);
    // Field 1: position_lat (sint32, 4 bytes)
    def.add([0x00, 0x04, 0x85]);
    // Field 2: position_long (sint32, 4 bytes)
    def.add([0x01, 0x04, 0x85]);
    // Field 3: altitude (uint16, 2 bytes)
    def.add([0x02, 0x02, 0x84]);
    // Field 4: heart_rate (uint8, 1 byte)
    def.add([0x03, 0x01, 0x02]);
    // Field 5: cadence (uint8, 1 byte)
    def.add([0x04, 0x01, 0x02]);
    // Field 6: distance (uint32, 4 bytes)
    def.add([0x05, 0x04, 0x86]);
    // Field 7: speed (uint16, 2 bytes)
    def.add([0x06, 0x02, 0x84]);

    builder.add(def.toBytes());

    // Data Messages for each trackpoint
    for (final point in activity.trackPoints) {
      final data = ByteData(23);
      data.setUint8(0, 0x02); // Data, local mesg 2
      data.setUint32(1, _toFitTimestamp(point.timestamp), Endian.little);

      // Lat/Long in Semicircles (degrees * (2^31 / 180))
      final latSemicircles = (point.latitude * (2147483648.0 / 180.0)).round();
      final lonSemicircles = (point.longitude * (2147483648.0 / 180.0)).round();
      data.setInt32(5, latSemicircles, Endian.little);
      data.setInt32(9, lonSemicircles, Endian.little);

      // Altitude: (altitude + 500) * 5 (uint16)
      final altVal = point.elevation != null ? ((point.elevation! + 500.0) * 5.0).clamp(0, 65535).round() : 0xFFFF;
      data.setUint16(13, altVal, Endian.little);

      // Heart Rate (uint8)
      data.setUint8(15, point.heartRate ?? 0xFF);

      // Cadence (uint8)
      data.setUint8(16, point.cadence ?? 0xFF);

      // Distance in cm (100 * meters)
      final distVal = point.distanceMeters != null ? (point.distanceMeters! * 100.0).round() : 0xFFFFFFFF;
      data.setUint32(17, distVal, Endian.little);

      // Speed in mm/s (1000 * m/s)
      final speedVal = point.speed != null ? (point.speed! * 1000.0).clamp(0, 65535).round() : 0xFFFF;
      data.setUint16(21, speedVal, Endian.little);

      builder.add(data.buffer.asUint8List());
    }
  }

  static void _writeLapMessage(BytesBuilder builder, WorkoutActivity activity) {
    // Definition Message for Lap (Global Mesg Num 19)
    // Local mesg 3: timestamp(253), start_time(2), total_elapsed_time(7), total_timer_time(8), total_distance(9), total_calories(11), avg_heart_rate(15), max_heart_rate(16)
    final def = BytesBuilder();
    def.addByte(0x43); // Definition, local mesg 3
    def.addByte(0x00);
    def.addByte(0x00);
    def.add([0x13, 0x00]); // Global Mesg Num = 19 (Lap)
    def.addByte(8);

    def.add([0xFD, 0x04, 0x86]); // timestamp (uint32)
    def.add([0x02, 0x04, 0x86]); // start_time (uint32)
    def.add([0x07, 0x04, 0x86]); // total_elapsed_time (uint32, 1000 * s)
    def.add([0x08, 0x04, 0x86]); // total_timer_time (uint32, 1000 * s)
    def.add([0x09, 0x04, 0x86]); // total_distance (uint32, 100 * m)
    def.add([0x0B, 0x02, 0x84]); // total_calories (uint16)
    def.add([0x0F, 0x01, 0x02]); // avg_heart_rate (uint8)
    def.add([0x10, 0x01, 0x02]); // max_heart_rate (uint8)

    builder.add(def.toBytes());

    // Data Message
    final data = ByteData(25);
    data.setUint8(0, 0x03); // Data, local mesg 3
    data.setUint32(1, _toFitTimestamp(activity.endTime), Endian.little);
    data.setUint32(5, _toFitTimestamp(activity.startTime), Endian.little);

    final durationMs = (activity.totalDurationSeconds > 0 ? activity.totalDurationSeconds : activity.duration.inSeconds) * 1000;
    data.setUint32(9, durationMs, Endian.little);
    data.setUint32(13, durationMs, Endian.little);

    final distCm = (activity.totalDistanceMeters * 100.0).round();
    data.setUint32(17, distCm, Endian.little);

    data.setUint16(21, activity.totalCalories.clamp(0, 65535), Endian.little);
    data.setUint8(23, activity.avgHeartRate ?? 0xFF);
    data.setUint8(24, activity.maxHeartRate ?? 0xFF);

    builder.add(data.buffer.asUint8List());
  }

  static void _writeSessionMessage(BytesBuilder builder, WorkoutActivity activity) {
    // Definition Message for Session (Global Mesg Num 18)
    // Local mesg 0 (redefined): timestamp(253), start_time(2), sport(5), total_elapsed_time(7), total_timer_time(8), total_distance(9), total_calories(11), avg_heart_rate(16), max_heart_rate(17)
    final def = BytesBuilder();
    def.addByte(0x40); // Definition, local mesg 0
    def.addByte(0x00);
    def.addByte(0x00);
    def.add([0x12, 0x00]); // Global Mesg Num = 18 (Session)
    def.addByte(9);

    def.add([0xFD, 0x04, 0x86]); // timestamp
    def.add([0x02, 0x04, 0x86]); // start_time
    def.add([0x05, 0x01, 0x00]); // sport (enum)
    def.add([0x07, 0x04, 0x86]); // total_elapsed_time (1000 * s)
    def.add([0x08, 0x04, 0x86]); // total_timer_time (1000 * s)
    def.add([0x09, 0x04, 0x86]); // total_distance (100 * m)
    def.add([0x0B, 0x02, 0x84]); // total_calories
    def.add([0x10, 0x01, 0x02]); // avg_heart_rate
    def.add([0x11, 0x01, 0x02]); // max_heart_rate

    builder.add(def.toBytes());

    // Data Message
    final data = ByteData(26);
    data.setUint8(0, 0x00);
    data.setUint32(1, _toFitTimestamp(activity.endTime), Endian.little);
    data.setUint32(5, _toFitTimestamp(activity.startTime), Endian.little);
    data.setUint8(9, _toFitSport(activity.sportType));

    final durationMs = (activity.totalDurationSeconds > 0 ? activity.totalDurationSeconds : activity.duration.inSeconds) * 1000;
    data.setUint32(10, durationMs, Endian.little);
    data.setUint32(14, durationMs, Endian.little);

    final distCm = (activity.totalDistanceMeters * 100.0).round();
    data.setUint32(18, distCm, Endian.little);

    data.setUint16(22, activity.totalCalories.clamp(0, 65535), Endian.little);
    data.setUint8(24, activity.avgHeartRate ?? 0xFF);
    data.setUint8(25, activity.maxHeartRate ?? 0xFF);

    builder.add(data.buffer.asUint8List());
  }

  static void _writeActivityMessage(BytesBuilder builder, WorkoutActivity activity) {
    // Definition Message for Activity (Global Mesg Num 34)
    // Local mesg 1 (redefined): timestamp(253), total_timer_time(0), num_sessions(1), type(2)
    final def = BytesBuilder();
    def.addByte(0x41); // Definition, local mesg 1
    def.addByte(0x00);
    def.addByte(0x00);
    def.add([0x22, 0x00]); // Global Mesg Num = 34 (Activity)
    def.addByte(4);

    def.add([0xFD, 0x04, 0x86]); // timestamp
    def.add([0x00, 0x04, 0x86]); // total_timer_time (1000 * s)
    def.add([0x01, 0x02, 0x84]); // num_sessions (uint16)
    def.add([0x02, 0x01, 0x00]); // type (enum)

    builder.add(def.toBytes());

    // Data Message
    final data = ByteData(12);
    data.setUint8(0, 0x01);
    data.setUint32(1, _toFitTimestamp(activity.endTime), Endian.little);

    final durationMs = (activity.totalDurationSeconds > 0 ? activity.totalDurationSeconds : activity.duration.inSeconds) * 1000;
    data.setUint32(5, durationMs, Endian.little);
    data.setUint16(9, 1, Endian.little); // 1 session
    data.setUint8(11, 0); // 0 = generic/manual

    builder.add(data.buffer.asUint8List());
  }

  static int _toFitTimestamp(DateTime dt) {
    return (dt.toUtc().millisecondsSinceEpoch ~/ 1000) - _fitEpochOffset;
  }

  static int _toFitSport(ActivityType type) {
    switch (type) {
      case ActivityType.outdoorRunning:
      case ActivityType.indoorRunning:
      case ActivityType.trailRunning:
        return 1; // FIT sport: running
      case ActivityType.outdoorCycling:
      case ActivityType.indoorCycling:
        return 2; // FIT sport: cycling
      case ActivityType.walking:
      case ActivityType.hiking:
        return 11; // FIT sport: walking / hiking
      case ActivityType.swimming:
        return 5; // FIT sport: swimming
      case ActivityType.crossTrainer:
        return 13; // FIT sport: fitness equipment
      default:
        return 0; // generic
    }
  }

  static int _computeCrc(Uint8List data) {
    int crc = 0;
    final crcTable = [
      0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
      0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
    ];

    for (final byte in data) {
      // Compute CRC for lower 4 bits
      int tmp = crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ crcTable[byte & 0xF];

      // Compute CRC for upper 4 bits
      tmp = crcTable[crc & 0xF];
      crc = (crc >> 4) & 0x0FFF;
      crc = crc ^ tmp ^ crcTable[(byte >> 4) & 0xF];
    }

    return crc;
  }
}
