package com.example.song_downloder

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.ffmpegkit_maintained.ytdlp.DownloadProgressCallback
import dev.ffmpegkit_maintained.ytdlp.YtDlp
import dev.ffmpegkit_maintained.ytdlp.YtDlpRequest
import dev.ffmpegkit_maintained.ytdlp.YtDlpResponse
import java.io.File
import java.util.concurrent.Future

class MainActivity : FlutterActivity() {
    private val channelName = "song_downloader/native"
    private val cookiePickerRequest = 4101
    private var activeJob: Future<YtDlpResponse>? = null
    private var cookiePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            YtDlp.init(applicationContext)
        } catch (e: Exception) {
            android.util.Log.e("SongDownloader", "yt-dlp initialization failed", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickCookies" -> pickCookies(result)
                    "downloadAudio" -> {
                        val url = call.argument<String>("url")?.trim()
                        val cookiesPath = call.argument<String>("cookiesPath")?.trim()
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL is required", null)
                            return@setMethodCallHandler
                        }
                        startDownload(url, cookiesPath, result, flutterEngine)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickCookies(result: MethodChannel.Result) {
        if (cookiePickerResult != null) {
            result.error("BUSY", "File picker is already open", null)
            return
        }
        cookiePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/*"
        }
        startActivityForResult(intent, cookiePickerRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != cookiePickerRequest) return

        val callback = cookiePickerResult
        cookiePickerResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback?.success(null)
            return
        }

        val uri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
            // Some providers do not support persistable permissions.
        }

        // yt-dlp expects a filesystem path. Copy the selected file into app storage.
        try {
            val cookiesDir = File(filesDir, "cookies")
            if (!cookiesDir.exists()) cookiesDir.mkdirs()
            val destination = File(cookiesDir, "youtube-cookies.txt")
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) throw IllegalStateException("Could not open selected file")
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            callback?.success(destination.absolutePath)
        } catch (e: Exception) {
            callback?.error("COOKIE_FILE", e.message ?: "Could not import cookies file", null)
        }
    }

    private fun startDownload(
        url: String,
        cookiesPath: String?,
        result: MethodChannel.Result,
        flutterEngine: FlutterEngine
    ) {
        if (activeJob != null && !activeJob!!.isDone) {
            result.error("BUSY", "A download is already running", null)
            return
        }

        val musicDir = File(getExternalFilesDir(null), "Music/SongDownloader")
        if (!musicDir.exists() && !musicDir.mkdirs()) {
            result.error("STORAGE", "Could not create download directory", null)
            return
        }

        val outputTemplate = File(musicDir, "%(title)s.%(ext)s").absolutePath
        val request = YtDlpRequest(url)
            .setOutputTemplate(outputTemplate)
            .addOption("-f", "bestaudio/best")
            .addOption("--no-playlist")
            .addOption("--newline")
            .addOption("--restrict-filenames")

        // The current yt-dlp Android free AAR exposes cookies as its supported
        // YouTube authentication workaround. Do not pretend that unsupported
        // extractor arguments are being applied: the AAR's option bridge ignores
        // unknown flags.
        if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
            request.addOption("--cookies", cookiesPath)
        }

        try {
            YtDlp.init(applicationContext)
            activeJob = YtDlp.executeAsync(request, object : DownloadProgressCallback {
                override fun onProgressUpdate(progress: Float, etaInSeconds: Long, line: String) {
                    android.os.Handler(mainLooper).post {
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                            .invokeMethod(
                                "downloadProgress",
                                mapOf("progress" to progress, "eta" to etaInSeconds, "line" to line)
                            )
                    }
                }
            })

            Thread {
                try {
                    val response = activeJob?.get()
                    val exitCode = response?.exitCode ?: -1
                    runOnUiThread {
                        if (exitCode == 0) {
                            val newest = musicDir.listFiles()
                                ?.filter { it.isFile && !it.name.endsWith(".part") }
                                ?.maxByOrNull { it.lastModified() }
                            result.success(
                                mapOf(
                                    "success" to true,
                                    "path" to newest?.absolutePath
                                )
                            )
                        } else {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "error" to "yt-dlp could not download this media. Exit code: $exitCode. If YouTube returns 403, import a current Netscape-format YouTube cookies file and retry."
                                )
                            )
                        }
                        activeJob = null
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.success(
                            mapOf(
                                "success" to false,
                                "error" to (e.message ?: "Download failed")
                            )
                        )
                        activeJob = null
                    }
                }
            }.start()
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message ?: "Could not start download", null)
        }
    }
}
