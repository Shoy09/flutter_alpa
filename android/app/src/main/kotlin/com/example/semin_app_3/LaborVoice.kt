package com.example.i_miner

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.util.concurrent.Executors
import java.util.zip.ZipInputStream

/** One short, offline dictation. No network recognizer or runtime downloads. */
class LaborVoice(private val activity: Activity) {
    companion object { const val PERMISSION = 730 }
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var speech: SpeechService? = null
    private var generation = 0
    private var closed = false
    private var lastPartial = ""

    fun handle(method: String, result: MethodChannel.Result) {
        when (method) {
            "escuchar" -> {
                if (pending != null) {
                    result.error("busy", "El micrófono ya está activo.", null)
                    return
                }
                pending = result
                if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION)
                } else prepare()
            }
            "cancelar" -> { cancel(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    fun permission(granted: Boolean) {
        if (pending == null) return
        if (granted) prepare()
        else finish(error = "Se necesita permiso de micrófono. Puedes habilitarlo en Ajustes.")
    }

    private fun prepare() {
        val request = ++generation
        worker.execute {
            try {
                if (model == null) {
                    val root = File(activity.filesDir, "labor-voz-es-0.42")
                    val folder = File(root, "vosk-model-small-es-0.42")
                    val ready = File(root, "ready")
                    if (!ready.exists()) {
                        root.mkdirs()
                        ZipInputStream(activity.assets.open("model-es.zip")).use { zip ->
                            var entry = zip.nextEntry
                            while (entry != null) {
                                val target = File(root, entry.name)
                                check(target.canonicalPath.startsWith(root.canonicalPath + File.separator))
                                if (entry.isDirectory) target.mkdirs()
                                else {
                                    target.parentFile?.mkdirs()
                                    target.outputStream().use { zip.copyTo(it) }
                                }
                                zip.closeEntry()
                                entry = zip.nextEntry
                            }
                        }
                        ready.writeText("0.42")
                    }
                    model = Model(folder.absolutePath)
                }
                main.post {
                    if (!closed && request == generation && pending != null) start(request)
                }
            } catch (e: Exception) {
                main.post {
                    if (request == generation) finish(error = "No se pudo preparar la voz sin conexión: ${e.message}")
                }
            }
        }
    }

    private fun start(request: Int) {
        try {
            lastPartial = ""
            recognizer = Recognizer(model, 16000f)
            speech = SpeechService(recognizer, 16000f)
            val listener = object : RecognitionListener {
                private fun active() = request == generation && pending != null
                private fun text(json: String, key: String) = JSONObject(json).optString(key).trim()
                override fun onPartialResult(hypothesis: String) {
                    if (active()) lastPartial = text(hypothesis, "partial")
                }
                override fun onResult(hypothesis: String) {
                    if (!active()) return
                    val words = text(hypothesis, "text")
                    if (words.isNotEmpty()) finish(words)
                }
                override fun onFinalResult(hypothesis: String) {
                    if (active()) finish(text(hypothesis, "text").ifEmpty { lastPartial })
                }
                override fun onError(exception: Exception) {
                    if (active()) finish(error = "No se pudo usar el micrófono: ${exception.message}")
                }
                override fun onTimeout() {
                    if (active()) {
                        if (lastPartial.isEmpty()) finish(error = "No se entendió la labor. Acérquese al micrófono y vuelva a intentarlo.")
                        else finish(lastPartial)
                    }
                }
            }
            check(speech!!.startListening(listener, 15000))
        } catch (e: Exception) {
            finish(error = "No se pudo iniciar el micrófono: ${e.message}")
        }
    }

    private fun finish(text: String = "", error: String? = null) {
        val result = pending
        pending = null
        generation++
        speech?.cancel()
        speech?.shutdown()
        speech = null
        recognizer?.close()
        recognizer = null
        if (error != null) result?.error("voice_error", error, null)
        else result?.success(text)
    }

    fun cancel() = finish()

    fun close() {
        closed = true
        cancel()
        worker.execute { model?.close(); model = null }
        worker.shutdown()
    }
}
