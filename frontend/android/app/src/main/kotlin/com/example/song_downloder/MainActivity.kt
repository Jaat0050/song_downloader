package com.example.song_downloder

import com.ryanheise.audioservice.AudioServiceActivity
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class MainActivity : AudioServiceActivity() {
    private val channelName = "song_downloader/local_server"
    private var serverUrl: String? = null
    private var pythonStarted = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startServer" -> startServer(result)
                    "getServerUrl" -> result.success(serverUrl)
                    "stopServer" -> {
                        stopServer()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startServer(result: MethodChannel.Result) {
        try {
            if (!pythonStarted) {
                if (!Python.isStarted()) {
                    Python.start(AndroidPlatform(this))
                }
                pythonStarted = true
            }

            val python = Python.getInstance()
            val module = python.getModule("local_server")
            val filesDir = filesDir.absolutePath
            val url = module.callAttr("start_server", filesDir).toString()
            serverUrl = url
            result.success(url)
        } catch (e: Exception) {
            result.error("SERVER_START_FAILED", e.message ?: "Unable to start local server", null)
        }
    }

    private fun stopServer() {
        try {
            if (pythonStarted && Python.isStarted()) {
                Python.getInstance().getModule("local_server").callAttr("stop_server")
            }
        } catch (_: Exception) {
            // Best effort during activity shutdown.
        }
    }

    override fun onDestroy() {
        stopServer()
        super.onDestroy()
    }
}
