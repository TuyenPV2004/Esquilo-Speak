package com.esquilospeak.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.time.ZoneId

class MainActivity : FlutterActivity() {
    private val channelName = "com.esquilospeak.mobile/advanced_learning"
    private val executor = Executors.newSingleThreadExecutor()
    private var player: MediaPlayer? = null
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var permissionResult: MethodChannel.Result? = null
    private var permissionRequestCode = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(com.tekartik.sqflite.SqflitePlugin())
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "systemTimezone" -> result.success(ZoneId.systemDefault().id)
            "playRemoteMedia" -> playRemoteMedia(call, result)
            "downloadMedia" -> downloadMedia(call, result)
            "playDownloadedMedia" -> playDownloadedMedia(call, result)
            "requestMicrophonePermission" -> requestPermission(
                Manifest.permission.RECORD_AUDIO,
                microphonePermissionRequest,
                result,
            )
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "scheduleDailyReminder" -> scheduleReminder(call, result)
            "cancelDailyReminder" -> {
                LearningReminderScheduler.cancel(this)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun playRemoteMedia(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url") ?: return invalidArgument(result)
        val token = call.argument<String>("token") ?: return invalidArgument(result)
        try {
            releasePlayer()
            player = MediaPlayer().apply {
                setDataSource(
                    this@MainActivity,
                    Uri.parse(url),
                    mapOf("Authorization" to "Bearer $token"),
                )
                setOnPreparedListener {
                    it.start()
                    result.success(null)
                }
                setOnErrorListener { _, what, extra ->
                    result.error(
                        "MEDIA_PLAYBACK_FAILED",
                        "Media playback failed ($what/$extra).",
                        null,
                    )
                    true
                }
                prepareAsync()
            }
        } catch (error: Exception) {
            result.error("MEDIA_PLAYBACK_FAILED", error.message, null)
        }
    }

    private fun downloadMedia(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url") ?: return invalidArgument(result)
        val token = call.argument<String>("token") ?: return invalidArgument(result)
        val mediaId = call.argument<String>("mediaId") ?: return invalidArgument(result)
        executor.execute {
            val target = mediaFile(mediaId)
            var partial: File? = null
            var connection: HttpURLConnection? = null
            try {
                target.parentFile?.mkdirs()
                val part = File.createTempFile("${target.name}-", ".part", target.parentFile)
                partial = part
                connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 5_000
                connection.readTimeout = 15_000
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.setRequestProperty("Accept", "audio/wav")
                val responseCode = connection.responseCode
                if (responseCode !in 200..299) {
                    throw IllegalStateException("Media download returned HTTP $responseCode.")
                }
                val contentType = connection.contentType.orEmpty()
                if (!contentType.startsWith("audio/")) {
                    throw IllegalStateException("Media download did not return audio.")
                }
                connection.inputStream.use { input ->
                    part.outputStream().use(input::copyTo)
                }
                if (target.exists() && !target.delete()) {
                    throw IllegalStateException("Existing media could not be replaced.")
                }
                if (!part.renameTo(target)) {
                    throw IllegalStateException("Downloaded media could not be saved.")
                }
                runOnUiThread { result.success(null) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("MEDIA_DOWNLOAD_FAILED", error.message, null)
                }
            } finally {
                connection?.disconnect()
                partial?.takeIf(File::exists)?.delete()
            }
        }
    }

    private fun playDownloadedMedia(call: MethodCall, result: MethodChannel.Result) {
        val mediaId = call.argument<String>("mediaId") ?: return invalidArgument(result)
        val file = mediaFile(mediaId)
        if (!file.exists()) {
            result.error("MEDIA_NOT_DOWNLOADED", "Downloaded media was not found.", null)
            return
        }
        try {
            releasePlayer()
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnPreparedListener {
                    it.start()
                    result.success(null)
                }
                setOnErrorListener { _, what, extra ->
                    result.error(
                        "MEDIA_PLAYBACK_FAILED",
                        "Media playback failed ($what/$extra).",
                        null,
                    )
                    true
                }
                prepareAsync()
            }
        } catch (error: Exception) {
            result.error("MEDIA_PLAYBACK_FAILED", error.message, null)
        }
    }

    @Suppress("DEPRECATION")
    private fun startRecording(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("MICROPHONE_PERMISSION_REQUIRED", "Microphone permission is required.", null)
            return
        }
        if (recorder != null) {
            result.error("RECORDING_ALREADY_ACTIVE", "A recording is already active.", null)
            return
        }
        try {
            val output = File.createTempFile("pronunciation-", ".m4a", cacheDir)
            recordingFile = output
            recorder = (
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    MediaRecorder(this)
                } else {
                    MediaRecorder()
                }
            ).apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setPrivacySensitive(true)
                }
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(96_000)
                setAudioSamplingRate(44_100)
                setOutputFile(output.absolutePath)
                prepare()
                start()
            }
            result.success(null)
        } catch (error: Exception) {
            releaseRecorder(deleteFile = true)
            result.error("RECORDING_START_FAILED", error.message, null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val activeRecorder = recorder
        val output = recordingFile
        if (activeRecorder == null || output == null) {
            result.error("RECORDING_NOT_ACTIVE", "No recording is active.", null)
            return
        }
        try {
            activeRecorder.stop()
            activeRecorder.release()
            recorder = null
            recordingFile = null
            val encoded = Base64.encodeToString(output.readBytes(), Base64.NO_WRAP)
            output.delete()
            result.success(encoded)
        } catch (error: Exception) {
            releaseRecorder(deleteFile = true)
            result.error("RECORDING_STOP_FAILED", error.message, null)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        requestPermission(
            Manifest.permission.POST_NOTIFICATIONS,
            notificationPermissionRequest,
            result,
        )
    }

    private fun requestPermission(
        permission: String,
        requestCode: Int,
        result: MethodChannel.Result,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("PERMISSION_REQUEST_ACTIVE", "Another permission request is active.", null)
            return
        }
        permissionResult = result
        permissionRequestCode = requestCode
        requestPermissions(arrayOf(permission), requestCode)
    }

    private fun scheduleReminder(call: MethodCall, result: MethodChannel.Result) {
        val hour = call.argument<Int>("hour") ?: return invalidArgument(result)
        val minute = call.argument<Int>("minute") ?: return invalidArgument(result)
        val title = call.argument<String>("title") ?: return invalidArgument(result)
        val body = call.argument<String>("body") ?: return invalidArgument(result)
        LearningReminderScheduler.schedule(this, hour, minute, title, body)
        result.success(null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val pending = permissionResult
        permissionResult = null
        permissionRequestCode = 0
        pending?.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    override fun onDestroy() {
        releasePlayer()
        releaseRecorder(deleteFile = true)
        executor.shutdownNow()
        permissionResult = null
        super.onDestroy()
    }

    private fun mediaFile(mediaId: String): File {
        val safeName = mediaId.replace(Regex("[^a-zA-Z0-9_-]"), "_")
        return File(File(filesDir, "learning-media"), "$safeName.wav")
    }

    private fun releasePlayer() {
        player?.release()
        player = null
    }

    private fun releaseRecorder(deleteFile: Boolean) {
        try {
            recorder?.release()
        } catch (_: Exception) {
            // Resource cleanup is best-effort.
        }
        recorder = null
        if (deleteFile) recordingFile?.delete()
        recordingFile = null
    }

    private fun invalidArgument(result: MethodChannel.Result) {
        result.error("INVALID_ARGUMENT", "A required argument is missing.", null)
    }

    companion object {
        private const val microphonePermissionRequest = 8101
        private const val notificationPermissionRequest = 8102
    }
}
