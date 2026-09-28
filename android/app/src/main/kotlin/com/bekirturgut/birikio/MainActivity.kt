package com.bekirturgut.birikio

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.bekirturgut.birikio/documents"
    private val saveRequestCode = 8417
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveDocument") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("busy", "A file save is already in progress.", null)
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val mimeType = call.argument<String>("mimeType")
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
                    result.error("invalid", "Missing file name, type or contents.", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                pendingSave = result
                pendingBytes = bytes
                try {
                    startActivityForResult(intent, saveRequestCode)
                } catch (error: Exception) {
                    pendingSave = null
                    pendingBytes = null
                    result.error("picker", error.message, null)
                }
            }
    }

    @Deprecated("Activity result callback is required by FlutterActivity's host API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequestCode) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        pendingSave = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
            result.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(data.data!!)
                ?: throw IllegalStateException("Selected document cannot be opened for writing.")
            stream.use { it.write(bytes) }
            result.success(true)
        } catch (error: Exception) {
            result.error("write", error.message, null)
        }
    }
}
