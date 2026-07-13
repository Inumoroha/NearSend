package com.inumoroha.nearsend

import android.content.ContentValues
import android.app.Activity
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "nearsend/android"
    private val chooseSaveDirectoryRequestCode = 42017
    private val androidPreferencesName = "nearsend_android"
    private val selectedSaveDirectoryUriKey = "selected_save_directory_uri"
    private val selectedSaveDirectoryNameKey = "selected_save_directory_name"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var pendingChooseSaveDirectoryResult: MethodChannel.Result? = null

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
                "chooseSaveDirectory" -> {
                    chooseSaveDirectory(result)
                }
                "saveToSelectedDirectory" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (sourcePath == null || fileName == null) {
                        result.error("bad_args", "sourcePath and fileName are required", null)
                    } else {
                        try {
                            result.success(saveToSelectedDirectory(sourcePath, fileName, mimeType))
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
                "startBackgroundReceiveService" -> {
                    startBackgroundReceiveService()
                    result.success(true)
                }
                "stopBackgroundReceiveService" -> {
                    BackgroundReceiveService.stop(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startBackgroundReceiveService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 42018)
        }
        BackgroundReceiveService.start(applicationContext)
    }

    private fun chooseSaveDirectory(result: MethodChannel.Result) {
        if (pendingChooseSaveDirectoryResult != null) {
            result.error("busy", "A directory picker is already open", null)
            return
        }
        pendingChooseSaveDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, chooseSaveDirectoryRequestCode)
        } catch (e: Exception) {
            pendingChooseSaveDirectoryResult = null
            result.error("picker_failed", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == chooseSaveDirectoryRequestCode) {
            val result = pendingChooseSaveDirectoryResult
            pendingChooseSaveDirectoryResult = null
            if (result == null) return
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return
            }

            val flags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            contentResolver.takePersistableUriPermission(uri, flags)
            val displayName = displayNameForTreeUri(uri)
            preferences().edit()
                .putString(selectedSaveDirectoryUriKey, uri.toString())
                .putString(selectedSaveDirectoryNameKey, displayName)
                .apply()
            result.success(displayName)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun saveToSelectedDirectory(
        sourcePath: String,
        fileName: String,
        mimeType: String,
    ): String? {
        val uriString = preferences().getString(selectedSaveDirectoryUriKey, null) ?: return null
        val treeUri = android.net.Uri.parse(uriString)
        val source = File(sourcePath)
        val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocumentId)
        val destinationUri = DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            mimeType,
            fileName,
        ) ?: throw IllegalStateException("Cannot create destination document")

        contentResolver.openOutputStream(destinationUri, "w").use { output ->
            if (output == null) throw IllegalStateException("Cannot open output stream")
            source.inputStream().use { it.copyTo(output) }
        }
        val directoryName = preferences().getString(
            selectedSaveDirectoryNameKey,
            displayNameForTreeUri(treeUri),
        ) ?: displayNameForTreeUri(treeUri)
        return "$directoryName/$fileName"
    }

    private fun displayNameForTreeUri(uri: android.net.Uri): String {
        val id = DocumentsContract.getTreeDocumentId(uri)
        if (id == "primary:") return "Internal storage"
        if (id.startsWith("primary:")) {
            return "Internal storage/${id.removePrefix("primary:")}"
        }
        return id.ifEmpty { "Selected folder" }
    }

    private fun preferences() = getSharedPreferences(androidPreferencesName, MODE_PRIVATE)

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
