import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/workout_activity.dart';
import '../parsers/motion_path_parser.dart';

class HuaweiCloudSession {
  final Map<String, String> cookies;
  final String? userId;
  final String? accountName;
  final DateTime loginTime;

  const HuaweiCloudSession({
    required this.cookies,
    this.userId,
    this.accountName,
    required this.loginTime,
  });

  String get cookieHeader => cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Map<String, dynamic> toJson() => {
    'cookies': cookies,
    'userId': userId,
    'accountName': accountName,
    'loginTime': loginTime.toIso8601String(),
  };

  factory HuaweiCloudSession.fromJson(Map<String, dynamic> json) {
    return HuaweiCloudSession(
      cookies: Map<String, String>.from(json['cookies'] as Map? ?? {}),
      userId: json['userId'] as String?,
      accountName: json['accountName'] as String?,
      loginTime: json['loginTime'] != null 
          ? DateTime.parse(json['loginTime'] as String) 
          : DateTime.now(),
    );
  }
}

class HuaweiCloudService {
  static const String _sessionFileName = 'huawei_cloud_session.json';
  static HuaweiCloudService? _instance;
  HuaweiCloudSession? _session;
  bool _isInitialized = false;

  HuaweiCloudService._();

  static HuaweiCloudService get instance {
    _instance ??= HuaweiCloudService._();
    return _instance!;
  }

  HuaweiCloudSession? get session => _session;
  bool get isConnected => _session != null && _session!.cookies.isNotEmpty;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          _session = HuaweiCloudSession.fromJson(jsonDecode(content));
        }
      }
    } catch (e) {
      debugPrint('Error loading Huawei Cloud session: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Saves the authenticated session after WebView login
  Future<void> saveSession(
    Map<String, String> cookies, {
    String? userId,
    String? accountName,
  }) async {
    _session = HuaweiCloudSession(
      cookies: cookies,
      userId: userId,
      accountName: accountName,
      loginTime: DateTime.now(),
    );
    await _saveToDisk();
  }

  /// Fetches workout activities directly from Huawei Health Cloud
  Future<List<WorkoutActivity>> fetchActivities({
    void Function(int current, int total, String status)? onProgress,
  }) async {
    if (!isConnected) {
      throw Exception('Huawei ID is not logged in. Please log in first.');
    }

    onProgress?.call(0, 0, 'Connecting to Huawei Health Cloud...');

    try {
      final List<WorkoutActivity> allActivities = [];
      final cookieHeader = _session!.cookieHeader;

      // Common headers mimicking browser session
      final headers = {
        'Cookie': cookieHeader,
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://cloud.huawei.com/',
        'Origin': 'https://cloud.huawei.com',
      };

      // Query Huawei Health cloud API endpoints
      // Endpoint 1: Motion / Health data records
      final endpoints = [
        'https://health.huawei.com/api/v1/health/motion/records',
        'https://cloud.huawei.com/api/v1/health/exercise/list',
        'https://id1.cloud.huawei.com/CAS/portal/health/records',
      ];

      dynamic responseData;

      for (final endpoint in endpoints) {
        try {
          final res = await http.get(Uri.parse(endpoint), headers: headers);
          if (res.statusCode == 200 && res.body.isNotEmpty) {
            responseData = jsonDecode(res.body);
            break;
          }
        } catch (_) {
          continue;
        }
      }

      if (responseData != null) {
        final parsed = MotionPathParser.parseJsonContent(responseData);
        allActivities.addAll(parsed);
      }

      onProgress?.call(allActivities.length, allActivities.length, 'Loaded ${allActivities.length} activities.');
      return allActivities;
    } catch (e) {
      debugPrint('Error fetching Huawei Cloud activities: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _session = null;
    final file = await _getSessionFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      if (_session != null) {
        final file = await _getSessionFile();
        await file.writeAsString(jsonEncode(_session!.toJson()));
      }
    } catch (e) {
      debugPrint('Error saving Huawei Cloud session: $e');
    }
  }

  Future<File> _getSessionFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_sessionFileName');
  }
}
