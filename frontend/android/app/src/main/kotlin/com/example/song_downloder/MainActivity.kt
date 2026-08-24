package com.example.song_downloder

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform

class MainActivity : AudioServiceActivity() {
    private val channelName = "song_downloader/local_server"
    private var serverUrl: String? = null
    private var pythonStarted = false
    private var initialSharedText: String? = null
    private var flutterChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        initialSharedText = extractSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        flutterChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> startServer(result)
                "getServerUrl" -> result.success(serverUrl)
                "getInitialSharedText" -> {
                    result.success(initialSharedText)
                    initialSharedText = null
                }
                "stopServer" -> {
                    stopServer()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sharedText = extractSharedText(intent) ?: return
        flutterChannel?.invokeMethod("sharedText", sharedText)
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type != null && intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
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
