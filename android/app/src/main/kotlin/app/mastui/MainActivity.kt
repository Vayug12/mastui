package app.mastui

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.graphics.Color
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val downloadChannel = "app.mastui/design-download"
        private const val writePermissionRequest = 4101
        private const val pngMimeType = "image/png"
    }

    private data class PendingDownload(
        val bytes: ByteArray,
        val fileName: String,
        val result: MethodChannel.Result,
    )

    private var pendingDownload: PendingDownload? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep the Android 3-button area transparent even after an AppBar
        // updates Flutter's system overlay style on a pushed route.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                    } else {
                        0
                    }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                if (bytes == null || bytes.isEmpty() || fileName.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "No image data was provided.", null)
                    return@setMethodCallHandler
                }

                saveImage(bytes, fileName, result)
            }
    }

    private fun saveImage(bytes: ByteArray, fileName: String, result: MethodChannel.Result) {
        if (
            Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
                checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                    PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingDownload != null) {
                result.error("DOWNLOAD_IN_PROGRESS", "Please finish the current download first.", null)
                return
            }
            pendingDownload = PendingDownload(bytes, fileName, result)
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                writePermissionRequest,
            )
            return
        }

        writeImage(bytes, fileName, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != writePermissionRequest) return

        val pending = pendingDownload ?: return
        pendingDownload = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            writeImage(pending.bytes, pending.fileName, pending.result)
        } else {
            pending.result.error(
                "STORAGE_PERMISSION_DENIED",
                "Storage permission is needed to save the image.",
                null,
            )
        }
    }

    private fun writeImage(bytes: ByteArray, fileName: String, result: MethodChannel.Result) {
        try {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(bytes, fileName)
            } else {
                saveLegacy(bytes, fileName)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message ?: "The image could not be saved.", null)
        }
    }

    private fun saveWithMediaStore(bytes: ByteArray, fileName: String): Uri {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, pngMimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}${File.separator}MastUI",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create the download file.")

        try {
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not open the download file.")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(bytes: ByteArray, fileName: String): Uri {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "MastUI",
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Could not create the Downloads/MastUI folder.")
        }
        val imageFile = File(directory, fileName)
        FileOutputStream(imageFile).use { it.write(bytes) }
        MediaScannerConnection.scanFile(this, arrayOf(imageFile.path), arrayOf(pngMimeType), null)
        return Uri.fromFile(imageFile)
    }
}
