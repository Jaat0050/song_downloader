package com.example.song_downloder

import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode

/**
 * Thin Android bridge used by the embedded Python backend to transcode the
 * downloaded YouTube audio stream to MP3 without requiring a standalone
 * ffmpeg executable inside the APK.
 */
object AudioTranscoder {
    @JvmStatic
    fun transcodeToMp3(inputPath: String, outputPath: String): Boolean {
        val input = quote(inputPath)
        val output = quote(outputPath)
        val command = "-y -i $input -vn -map_metadata 0 -codec:a libmp3lame -b:a 320k $output"
        val session = FFmpegKit.execute(command)
        return ReturnCode.isSuccess(session.returnCode)
    }

    private fun quote(value: String): String {
        return "'" + value.replace("'", "'\\''") + "'"
    }
}
