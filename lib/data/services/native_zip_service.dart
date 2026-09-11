import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeZipService {
  static const MethodChannel _channel = MethodChannel('com.huaweihealth.exporter/zip');

  /// Checks if a ZIP archive is password-protected/encrypted
  static Future<bool> isEncrypted(String zipPath) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isEncrypted', {
        'zipPath': zipPath,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking if ZIP is encrypted: $e');
      return false;
    }
  }

  /// Extracts a ZIP archive (with optional password for AES-256 / ZipCrypto)
  static Future<bool> extractZip({
    required String zipPath,
    required String destinationDir,
    String? password,
  }) async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMethod<bool>('extractZip', {
        'zipPath': zipPath,
        'destination': destinationDir,
        'password': password,
      });
      return result ?? false;
    } else {
      // macOS / Linux fallback: try system unzip
      try {
        final args = password != null && password.isNotEmpty
            ? ['-P', password, '-o', zipPath, '-d', destinationDir]
            : ['-o', zipPath, '-d', destinationDir];
        final res = await Process.run('unzip', args);
        return res.exitCode == 0;
      } catch (e) {
        debugPrint('Desktop unzip error: $e');
        return false;
      }
    }
  }
}
