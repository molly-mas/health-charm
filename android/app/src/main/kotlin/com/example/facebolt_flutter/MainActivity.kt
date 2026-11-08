package com.example.facebolt_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val picoReminder by lazy { PicoReminder(this) }
    private val modelFile by lazy { File(filesDir, "NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf") }
    private val copyExecutor = Executors.newSingleThreadExecutor()
    private var importResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "healthcharm/pico")
            .setMethodCallHandler { call, result ->
                if (call.method == "reminder") picoReminder.send(call.arguments as? String, result)
                else if (call.method == "sendFace") picoReminder.sendFace(call.arguments as? String, result)
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "facebolt/model")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "modelPath" -> result.success(modelFile.takeIf { it.isFile }?.absolutePath)
                    "openModelPage" -> {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(MODEL_URL)))
                        result.success(null)
                    }
                    "importModel" -> {
                        if (importResult != null) {
                            result.error("BUSY", "A model import is already in progress", null)
                        } else {
                            importResult = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, PICK_MODEL_REQUEST)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("The document picker result is delivered by this Android API")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MODEL_REQUEST) return
        val result = importResult ?: return
        importResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        copyExecutor.execute {
            try {
                result.success(copyVerifiedModel(uri))
            } catch (error: Exception) {
                result.error("IMPORT_FAILED", error.message ?: "Model import failed", null)
            }
        }
    }

    private fun copyVerifiedModel(uri: Uri): String {
        val available = StatFs(filesDir.path).availableBytes
        if (available < MIN_FREE_BYTES) {
            error("At least 3.2 GB of free storage is needed to import Nemotron")
        }
        val temporary = File(filesDir, "nemotron-import.tmp")
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            var total = 0L
            val input = contentResolver.openInputStream(uri)
                ?: error("Could not read the selected file")
            input.use { source ->
                FileOutputStream(temporary).use { target ->
                    val buffer = ByteArray(1024 * 1024)
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > MAX_MODEL_BYTES) error("Selected file is too large")
                        digest.update(buffer, 0, count)
                        target.write(buffer, 0, count)
                    }
                }
            }
            val hash = digest.digest().joinToString("") { "%02x".format(it) }
            if (hash != MODEL_SHA256) {
                error("Select NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf from NVIDIA's model page")
            }
            if (modelFile.exists() && !modelFile.delete()) {
                error("Could not replace the previous model")
            }
            if (!temporary.renameTo(modelFile)) {
                error("Could not save the verified model in app storage")
            }
            return modelFile.absolutePath
        } finally {
            if (temporary.exists()) temporary.delete()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PicoReminder.permissionRequest) picoReminder.permissionsResult(grantResults)
    }

    override fun onDestroy() {
        picoReminder.finish("HealthCharm closed")
        copyExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val PICK_MODEL_REQUEST = 7041
        private const val MODEL_URL = "https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF/blob/main/NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf"
        private const val MIN_FREE_BYTES = 3_200_000_000L
        private const val MAX_MODEL_BYTES = 3_200_000_000L
        private const val MODEL_SHA256 = "be5d9a656a51922f24f1f09a759cebb694e1f5d9728bf0ef9f8c972c5a0b5ef2"
    }
}
