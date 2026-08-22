package com.example.song_downloder

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.ffmpegkit_maintained.ytdlp.DownloadProgressCallback
import dev.ffmpegkit_maintained.ytdlp.YtDlp
import dev.ffmpegkit_maintained.ytdlp.YtDlpRequest
import java.io.File
import java.util.concurrent.Future

class MainActivity : FlutterActivity() {
    private val channelName = "song_downloader/native"
    private var activeJob: Future<*>? = null

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
                    "downloadAudio" -> {
                        val url = call.argument<String>("url")?.trim()
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "URL is required", null)
                            return@setMethodCallHandler
                        }
                        startDownload(url, result, flutterEngine)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startDownload(url: String, result: MethodChannel.Result, flutterEngine: FlutterEngine) {
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
            .addOption("-f", "bestaudio")
            .addOption("--no-playlist")
            .addOption("--newline")
            .addOption("--restrict-filenames")

        try {
            YtDlp.init(applicationContext)
            activeJob = YtDlp.executeAsync(request, object : DownloadProgressCallback {
                override fun onProgressUpdate(progress: Float, etaInSeconds: Long, line: String) {
                    flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
                        android.os.Handler(mainLooper).post {
                            MethodChannel(messenger, channelName).invokeMethod(
                                "downloadProgress",
                                mapOf("progress" to progress, "eta" to etaInSeconds, "line" to line)
                            )
                        }
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
                                ?.filter { it.isFile }
                                ?.maxByOrNull { it.lastModified() }
                            result.success(mapOf(
                                "success" to true,
                                "path" to newest?.absolutePath
                            ))
                        } else {
                            result.success(mapOf(
                                "success" to false,
                                "error" to "yt-dlp finished with exit code $exitCode"
                            ))
                        }
                        activeJob = null
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.success(mapOf("success" to false, "error" to (e.message ?: "Download failed")))
                        activeJob = null
                    }
                }
            }.start()
        } catch (e: Exception) {
            result.error("DOWNLOAD_ERROR", e.message ?: "Could not start download", null)
        }
    }
}
