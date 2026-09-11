import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ZipExtractResult {
  final bool success;
  final bool isWrongPassword;
  final String? errorMessage;

  ZipExtractResult({
    required this.success,
    this.isWrongPassword = false,
    this.errorMessage,
  });
}

class NativeZipService {
  static const MethodChannel _channel = MethodChannel('com.huaweihealth.exporter/zip');

  /// Checks if a ZIP archive is password-protected/encrypted
  static Future<bool> isEncrypted(String zipPath) async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('isEncrypted', {
          'zipPath': zipPath,
        });
        return result ?? false;
      } catch (e) {
        debugPrint('Error checking if ZIP is encrypted: $e');
        return false;
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      try {
        final res = await Process.run('zipinfo', ['-v', zipPath]);
        final output = res.stdout.toString();
        return output.contains('encrypted') || output.contains('u099') || output.contains('AES');
      } catch (e) {
        debugPrint('Desktop zipinfo error: $e');
        return false;
      }
    }
    return false;
  }

  /// Extracts a ZIP archive (with optional password for AES-256 / ZipCrypto)
  static Future<ZipExtractResult> extractZip({
    required String zipPath,
    required String destinationDir,
    String? password,
  }) async {
    if (Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('extractZip', {
          'zipPath': zipPath,
          'destination': destinationDir,
          'password': password,
        });
        return ZipExtractResult(success: result ?? false);
      } on PlatformException catch (e) {
        debugPrint('Native ZIP extract error [${e.code}]: ${e.message}');
        if (e.code == 'WRONG_PASSWORD') {
          return ZipExtractResult(
            success: false,
            isWrongPassword: true,
            errorMessage: 'Incorrect password for ZIP archive',
          );
        } else if (e.code == 'PASSWORD_REQUIRED') {
          return ZipExtractResult(
            success: false,
            isWrongPassword: true,
            errorMessage: 'Password is required for encrypted ZIP',
          );
        }
        return ZipExtractResult(
          success: false,
          errorMessage: e.message ?? 'Extraction failed',
        );
      } catch (e) {
        return ZipExtractResult(
          success: false,
          errorMessage: e.toString(),
        );
      }
    } else {
      // Desktop fallback (macOS / Linux): try 7z or unzip
      try {
        // Try 7z if installed (supports AES-256)
        final pArg = password != null && password.isNotEmpty ? '-p$password' : '-p';
        var res = await Process.run('7z', ['x', '-y', pArg, '-o$destinationDir', zipPath]);
        if (res.exitCode == 0) {
          return ZipExtractResult(success: true);
        }

        // Fallback to unzip
        final args = password != null && password.isNotEmpty
            ? ['-P', password, '-o', zipPath, '-d', destinationDir]
            : ['-o', zipPath, '-d', destinationDir];
        res = await Process.run('unzip', args);
        if (res.exitCode == 0) {
          return ZipExtractResult(success: true);
        } else if (res.exitCode == 82 || res.stderr.toString().contains('password')) {
          return ZipExtractResult(
            success: false,
            isWrongPassword: true,
            errorMessage: 'Incorrect password',
          );
        }
        return ZipExtractResult(
          success: false,
          errorMessage: res.stderr.toString().isNotEmpty ? res.stderr.toString() : 'Extraction failed',
        );
      } catch (e) {
        debugPrint('Desktop unzip error: $e');
        return ZipExtractResult(success: false, errorMessage: e.toString());
      }
    }
  }
}
