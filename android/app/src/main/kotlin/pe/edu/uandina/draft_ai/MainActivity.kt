package pe.edu.uandina.draft_ai

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val pdfWorker = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "draftai/pdf").setMethodCallHandler { call, result ->
            if (call.method !in listOf("info", "render")) { result.notImplemented(); return@setMethodCallHandler }
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.size > 15 * 1024 * 1024 || bytes.size < 5 || String(bytes.copyOfRange(0,5)) != "%PDF-") {
                result.error("invalid_pdf", "Invalid PDF", null); return@setMethodCallHandler
            }
            pdfWorker.execute {
                var temporary: File? = null
                try {
                    val temp = File.createTempFile("draftai_pdf_", ".pdf", cacheDir)
                    temporary = temp
                    temp.writeBytes(bytes)
                    ParcelFileDescriptor.open(temp, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            require(renderer.pageCount in 1..500)
                            if (call.method == "info") {
                                val pageCount = renderer.pageCount
                                runOnUiThread { result.success(pageCount) }
                            } else {
                                val index = call.argument<Int>("page") ?: 0
                                require(index in 0 until renderer.pageCount)
                                renderer.openPage(index).use { page ->
                                    val width = (call.argument<Int>("width") ?: 1200).coerceIn(200,1600)
                                    val height = (width.toLong() * page.height / page.width).toInt()
                                    require(height in 1..5000 && width.toLong()*height <= 6000000)
                                    val bitmap = Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
                                    try {
                                        bitmap.eraseColor(Color.WHITE)
                                        page.render(bitmap,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                        val output = ByteArrayOutputStream()
                                        bitmap.compress(Bitmap.CompressFormat.PNG,100,output)
                                        runOnUiThread { result.success(output.toByteArray()) }
                                    } finally { bitmap.recycle() }
                                }
                            }
                        }
                    }
                } catch (_: Exception) { runOnUiThread { result.error("invalid_pdf", "Cannot render this PDF", null) } }
                finally { temporary?.delete() }
            }
        }
    }
}
