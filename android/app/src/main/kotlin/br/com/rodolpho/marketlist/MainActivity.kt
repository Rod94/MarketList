package br.com.rodolpho.marketlist

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.provider.DocumentsContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID

class HistoryExportFileProvider : FileProvider()

class MainActivity : FlutterActivity() {
    private data class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result)

    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXPORT_CHANNEL)
            .setMethodCallHandler { call, result ->
                val name = call.argument<String>("fileName")
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || !EXPORT_NAME.matches(name) || bytes == null) {
                    result.error("invalid_export", "Planilha inválida.", null)
                } else {
                    try {
                        when (call.method) {
                            "save" -> saveSpreadsheet(name, bytes, result)
                            "share" -> {
                                shareSpreadsheet(name, bytes)
                                result.success(true)
                            }
                            else -> result.notImplemented()
                        }
                    } catch (error: Exception) {
                        result.error("export_failed", error.message, null)
                    }
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun saveSpreadsheet(name: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("export_busy", "Já existe uma exportação em andamento.", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = XLSX_MIME_TYPE
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pendingSave = PendingSave(bytes, result)
        try {
            startActivityForResult(intent, SAVE_REQUEST)
        } catch (error: Exception) {
            pendingSave = null
            throw error
        }
    }

    @Deprecated("FlutterActivity forwards results through this callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_REQUEST) return
        val save = pendingSave ?: return
        if (resultCode != Activity.RESULT_OK) {
            pendingSave = null
            save.result.success(false)
            return
        }
        val uri = data?.data
        if (uri == null) {
            pendingSave = null
            save.result.error("export_failed", "Destino indisponível.", null)
            return
        }
        Thread {
            val error = runCatching {
                val stream = contentResolver.openOutputStream(uri)
                    ?: throw IOException("Destino indisponível.")
                stream.use { it.write(save.bytes) }
            }.exceptionOrNull()
            if (error != null) {
                // Only the new document returned by ACTION_CREATE_DOCUMENT is eligible for cleanup.
                runCatching { DocumentsContract.deleteDocument(contentResolver, uri) }
            }
            runOnUiThread {
                pendingSave = null
                if (error == null) save.result.success(true)
                else save.result.error("export_failed", error.message, null)
            }
        }.start()
    }

    private fun shareSpreadsheet(name: String, bytes: ByteArray) {
        val root = File(cacheDir, "history-exports")
        val expiration = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
        root.listFiles()?.filter { it.lastModified() < expiration }?.forEach { it.deleteRecursively() }
        val folder = File(root, UUID.randomUUID().toString())
        try {
            if (!folder.mkdirs()) throw IOException("Cache indisponível.")
            val file = File(folder, name).apply { writeBytes(bytes) }
            val uri = FileProvider.getUriForFile(this, "$packageName.history_exports", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = XLSX_MIME_TYPE
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(name, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, null))
        } catch (error: Exception) {
            folder.deleteRecursively()
            throw error
        }
    }

    companion object {
        private const val EXPORT_CHANNEL = "br.com.rodolpho.marketlist/history_export"
        private const val XLSX_MIME_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        private const val SAVE_REQUEST = 6111
        private val EXPORT_NAME = Regex("MarketList-[-+0-9]+\\.xlsx")
    }
}
