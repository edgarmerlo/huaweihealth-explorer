package com.huaweihealth.huawei_health_export

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.lingala.zip4j.ZipFile
import net.lingala.zip4j.exception.ZipException
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.huaweihealth.exporter/zip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEncrypted" -> {
                    val zipPath = call.argument<String>("zipPath")
                    if (zipPath == null) {
                        result.error("INVALID_ARGS", "zipPath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(zipPath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "ZIP file not found at $zipPath", null)
                            return@setMethodCallHandler
                        }
                        val zipFile = ZipFile(zipPath)
                        result.success(zipFile.isEncrypted)
                    } catch (e: Exception) {
                        result.error("ZIP_ERROR", e.message, null)
                    }
                }
                "extractZip" -> {
                    val zipPath = call.argument<String>("zipPath")
                    val password = call.argument<String>("password")
                    val destination = call.argument<String>("destination")

                    if (zipPath == null || destination == null) {
                        result.error("INVALID_ARGS", "zipPath and destination are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val destDir = File(destination)
                            if (!destDir.exists()) {
                                destDir.mkdirs()
                            }

                            val zipFile = ZipFile(zipPath)
                            if (zipFile.isEncrypted) {
                                if (password.isNullOrEmpty()) {
                                    runOnUiThread {
                                        result.error("PASSWORD_REQUIRED", "Password is required for encrypted ZIP", null)
                                    }
                                    return@Thread
                                }
                                zipFile.setPassword(password.toCharArray())
                            }
                            zipFile.extractAll(destination)
                            runOnUiThread {
                                result.success(true)
                            }
                        } catch (e: ZipException) {
                            runOnUiThread {
                                if (e.type == ZipException.Type.WRONG_PASSWORD) {
                                    result.error("WRONG_PASSWORD", "Incorrect password for ZIP archive", null)
                                } else {
                                    result.error("ZIP_EXCEPTION", e.message, null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("EXTRACT_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
