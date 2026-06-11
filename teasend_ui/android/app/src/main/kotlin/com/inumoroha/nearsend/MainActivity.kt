package com.inumoroha.nearsend

import android.content.ContentValues
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "nearsend/android"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (sourcePath == null || fileName == null) {
                        result.error("bad_args", "sourcePath and fileName are required", null)
                    } else {
                        try {
                            result.success(saveToDownloads(sourcePath, fileName, mimeType))
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                }
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(true)
                }
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(true)
                }
                "getDeviceName" -> {
                    result.success(deviceName())
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Human-readable device name, e.g. "HUAWEI PCE-W30". */
    private fun deviceName(): String {
        val manufacturer = (Build.MANUFACTURER ?: "").trim()
        val model = (Build.MODEL ?: "").trim()
        val name = when {
            model.isEmpty() -> manufacturer
            manufacturer.isEmpty() -> model
            model.startsWith(manufacturer, ignoreCase = true) -> model
            else -> "$manufacturer $model"
        }
        return name.ifEmpty { "Android Device" }
    }

    /**
     * Copies [sourcePath] into the public Downloads/NearSend folder and returns
     * a human-readable destination path. Uses MediaStore on API 29+, and falls
     * back to direct file IO on older versions.
     */
    private fun saveToDownloads(sourcePath: String, fileName: String, mimeType: String): String {
        val source = File(sourcePath)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, "Download/NearSend")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert returned null")
            resolver.openOutputStream(uri).use { output ->
                if (output == null) throw IllegalStateException("Cannot open output stream")
                source.inputStream().use { it.copyTo(output) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Download/NearSend/$fileName"
        } else {
            @Suppress("DEPRECATION")
            val downloads = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            )
            val dir = File(downloads, "NearSend").apply { mkdirs() }
            val dest = File(dir, fileName)
            source.inputStream().use { input ->
                dest.outputStream().use { input.copyTo(it) }
            }
            return dest.absolutePath
        }
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("nearsend-discovery").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let { if (it.isHeld) it.release() }
        multicastLock = null
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }
}
