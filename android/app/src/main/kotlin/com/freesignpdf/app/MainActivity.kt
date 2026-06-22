package com.freesignpdf.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.freesignpdf.app/intent"
    private var intentData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getIncomingIntent") {
                result.success(intentData)
                // Consume the intent data so it doesn't open repeatedly
                intentData = null
            } else if (call.method == "resolveContentUri") {
                val uriString = call.argument<String>("uri")
                if (uriString != null) {
                    try {
                        val uri = Uri.parse(uriString)
                        val rawName = getFileName(uri) ?: "temp_scan.jpg"
                        val dotIndex = rawName.lastIndexOf('.')
                        val name = if (dotIndex != -1) rawName.substring(0, dotIndex) else rawName
                        val ext = if (dotIndex != -1) rawName.substring(dotIndex) else ".jpg"
                        val fileName = "${name}_${System.currentTimeMillis()}$ext"
                        val file = copyUriToTempFile(uri, fileName)
                        if (file != null) {
                            result.success(file.absolutePath)
                        } else {
                            result.error("COPY_FAILED", "Failed to copy URI to temp file", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URI string is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type
        
        if (Intent.ACTION_VIEW == action && type != null && type == "application/pdf") {
            val uri = intent.data ?: return
            val fileName = getFileName(uri) ?: "document.pdf"
            val file = copyUriToTempFile(uri, fileName) ?: return
            
            intentData = mapOf(
                "filePath" to file.absolutePath,
                "fileName" to fileName
            )
        }
    }

    private fun getFileName(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (columnIndex != -1) {
                        result = cursor.getString(columnIndex)
                    }
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/') ?: -1
            if (cut != -1) {
                result = result?.substring(cut + 1)
            }
        }
        return result
    }

    private fun copyUriToTempFile(uri: Uri, fileName: String): File? {
        return try {
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            val tempFile = File(cacheDir, fileName)
            val outputStream = FileOutputStream(tempFile)
            
            inputStream?.use { input ->
                outputStream.use { output ->
                    input.copyTo(output)
                }
            }
            tempFile
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
