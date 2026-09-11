import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/workout_activity.dart';
import '../generators/fit_generator.dart';

class StravaUploadResult {
  final bool success;
  final bool isDuplicate;
  final int? stravaActivityId;
  final String? uploadId;
  final String? errorMessage;

  const StravaUploadResult({
    required this.success,
    this.isDuplicate = false,
    this.stravaActivityId,
    this.uploadId,
    this.errorMessage,
  });
}

class StravaAuthCredentials {
  final String clientId;
  final String clientSecret;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresAt;
  final String? athleteName;

  const StravaAuthCredentials({
    required this.clientId,
    required this.clientSecret,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.athleteName,
  });

  bool get isConnected => accessToken != null && accessToken!.isNotEmpty;

  bool get isExpired {
    if (expiresAt == null) return true;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= (expiresAt! - 300); // 5 min margin
  }

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'clientSecret': clientSecret,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt,
    'athleteName': athleteName,
  };

  factory StravaAuthCredentials.fromJson(Map<String, dynamic> json) {
    return StravaAuthCredentials(
      clientId: json['clientId'] as String? ?? '',
      clientSecret: json['clientSecret'] as String? ?? '',
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] as int?,
      athleteName: json['athleteName'] as String?,
    );
  }
}

class StravaService {
  static const String _authFileName = 'strava_credentials.json';
  static StravaService? _instance;
  StravaAuthCredentials? _credentials;
  bool _isInitialized = false;

  StravaService._();

  static StravaService get instance {
    _instance ??= StravaService._();
    return _instance!;
  }

  StravaAuthCredentials? get credentials => _credentials;
  bool get isConnected => _credentials != null && _credentials!.isConnected;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getAuthFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          _credentials = StravaAuthCredentials.fromJson(jsonDecode(content));
        }
      }
    } catch (e) {
      debugPrint('Error loading Strava credentials: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Saves client credentials
  Future<void> saveClientCredentials(String clientId, String clientSecret) async {
    _credentials = StravaAuthCredentials(
      clientId: clientId.trim(),
      clientSecret: clientSecret.trim(),
      accessToken: _credentials?.accessToken,
      refreshToken: _credentials?.refreshToken,
      expiresAt: _credentials?.expiresAt,
      athleteName: _credentials?.athleteName,
    );
    await _saveToDisk();
  }

  /// Generates the Strava OAuth authorization URL
  Uri getAuthorizationUrl({required String redirectUri}) {
    if (_credentials == null || _credentials!.clientId.isEmpty) {
      throw Exception('Strava Client ID is not configured.');
    }

    return Uri.https('www.strava.com', '/oauth/authorize', {
      'client_id': _credentials!.clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'approval_prompt': 'auto',
      'scope': 'activity:write,activity:read_all',
    });
  }

  /// Opens authorization URL in browser
  Future<void> launchAuthInBrowser({required String redirectUri}) async {
    final url = getAuthorizationUrl(redirectUri: redirectUri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  /// Exchanges an OAuth authorization code or direct refresh token for access tokens
  Future<bool> authenticateWithCode(String code) async {
    if (_credentials == null || _credentials!.clientId.isEmpty || _credentials!.clientSecret.isEmpty) {
      throw Exception('Please configure your Strava Client ID and Client Secret first.');
    }

    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/token'),
        body: {
          'client_id': _credentials!.clientId,
          'client_secret': _credentials!.clientSecret,
          'code': code.trim(),
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final athlete = data['athlete'];
        final name = athlete != null ? '${athlete['firstname']} ${athlete['lastname']}' : null;

        _credentials = StravaAuthCredentials(
          clientId: _credentials!.clientId,
          clientSecret: _credentials!.clientSecret,
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresAt: data['expires_at'],
          athleteName: name,
        );
        await _saveToDisk();
        return true;
      } else {
        throw Exception('Strava auth error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Strava authentication failed: $e');
      rethrow;
    }
  }

  /// Ensures a fresh, valid access token
  Future<String> getValidAccessToken() async {
    if (_credentials == null || !_credentials!.isConnected) {
      throw Exception('Strava is not connected.');
    }

    if (!_credentials!.isExpired && _credentials!.accessToken != null) {
      return _credentials!.accessToken!;
    }

    // Refresh token
    final response = await http.post(
      Uri.parse('https://www.strava.com/oauth/token'),
      body: {
        'client_id': _credentials!.clientId,
        'client_secret': _credentials!.clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': _credentials!.refreshToken!,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _credentials = StravaAuthCredentials(
        clientId: _credentials!.clientId,
        clientSecret: _credentials!.clientSecret,
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'] ?? _credentials!.refreshToken,
        expiresAt: data['expires_at'],
        athleteName: _credentials!.athleteName,
      );
      await _saveToDisk();
      return _credentials!.accessToken!;
    } else {
      throw Exception('Failed to refresh Strava token: ${response.body}');
    }
  }

  /// Uploads a workout activity file to Strava
  Future<StravaUploadResult> uploadActivity(WorkoutActivity activity) async {
    try {
      final token = await getValidAccessToken();
      final fitBytes = FitGenerator.generate(activity);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.strava.com/api/v3/uploads'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['data_type'] = 'fit';
      request.fields['external_id'] = activity.externalFileName;
      request.fields['name'] = activity.title;
      request.fields['description'] = 'Exported from Huawei Health via Huawei Health Explorer';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fitBytes,
        filename: activity.externalFileName,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final uploadId = data['id']?.toString();
        final duplicateId = data['duplicate_activity_id'] as int?;

        if (duplicateId != null) {
          return StravaUploadResult(
            success: true,
            isDuplicate: true,
            stravaActivityId: duplicateId,
            uploadId: uploadId,
          );
        }

        // Poll upload status
        if (uploadId != null) {
          return await _pollUploadStatus(uploadId, token);
        }

        return StravaUploadResult(
          success: true,
          uploadId: uploadId,
          stravaActivityId: data['activity_id'] as int?,
        );
      } else {
        final errorBody = response.body;
        if (errorBody.toLowerCase().contains('duplicate')) {
          return const StravaUploadResult(success: true, isDuplicate: true);
        }
        return StravaUploadResult(
          success: false,
          errorMessage: 'Upload failed (${response.statusCode}): $errorBody',
        );
      }
    } catch (e) {
      return StravaUploadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Polls the upload status until processing finishes
  Future<StravaUploadResult> _pollUploadStatus(String uploadId, String token) async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final res = await http.get(
          Uri.parse('https://www.strava.com/api/v3/uploads/$uploadId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final status = data['status']?.toString() ?? '';
          final duplicateId = data['duplicate_activity_id'] as int?;
          final activityId = data['activity_id'] as int?;
          final error = data['error'];

          if (duplicateId != null) {
            return StravaUploadResult(
              success: true,
              isDuplicate: true,
              stravaActivityId: duplicateId,
              uploadId: uploadId,
            );
          }

          if (error != null && error.toString().isNotEmpty) {
            if (error.toString().toLowerCase().contains('duplicate')) {
              return StravaUploadResult(
                success: true,
                isDuplicate: true,
                uploadId: uploadId,
              );
            }
            return StravaUploadResult(
              success: false,
              uploadId: uploadId,
              errorMessage: error.toString(),
            );
          }

          if (activityId != null || status.toLowerCase().contains('ready')) {
            return StravaUploadResult(
              success: true,
              uploadId: uploadId,
              stravaActivityId: activityId,
            );
          }
        }
      } catch (_) {}
    }

    return StravaUploadResult(
      success: true,
      uploadId: uploadId,
    );
  }

  /// Checks if an activity exists on Strava (returns false if 404/deleted by user)
  Future<bool> checkActivityExists(int stravaActivityId) async {
    try {
      final token = await getValidAccessToken();
      final res = await http.get(
        Uri.parse('https://www.strava.com/api/v3/activities/$stravaActivityId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Deletes an activity on Strava (used to cleanly replace calibrated/modified workouts)
  Future<bool> deleteActivity(int stravaActivityId) async {
    try {
      final token = await getValidAccessToken();
      final res = await http.delete(
        Uri.parse('https://www.strava.com/api/v3/activities/$stravaActivityId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting activity on Strava: $e');
      return false;
    }
  }

  /// Updates existing activity title/description on Strava for modified records
  Future<bool> updateActivityMetadata(
    int stravaActivityId, {
    String? name,
    String? description,
  }) async {
    try {
      final token = await getValidAccessToken();
      final body = <String, String>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;

      final res = await http.put(
        Uri.parse('https://www.strava.com/api/v3/activities/$stravaActivityId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _credentials = null;
    final file = await _getAuthFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      if (_credentials != null) {
        final file = await _getAuthFile();
        await file.writeAsString(jsonEncode(_credentials!.toJson()));
      }
    } catch (e) {
      debugPrint('Error saving Strava credentials: $e');
    }
  }

  Future<File> _getAuthFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_authFileName');
  }
}
