package com.gdgoc.netrava.netrava_app

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "netrava.app/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    vibrator.cancel()
                    result.success(null)
                }
                "vibrateWaveform" -> {
                    val timings = (call.argument<List<Number>>("timings") ?: listOf()).map { it.toLong() }.toLongArray()
                    val amplitudes = (call.argument<List<Number>>("amplitudes") ?: listOf()).map { it.toInt() }.toIntArray()

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (vibrator.hasAmplitudeControl() && amplitudes.isNotEmpty() && amplitudes.size == timings.size) {
                            val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                            vibrator.vibrate(effect)
                        } else {
                            // Fallback hardware tanpa kendali amplitudo
                            val effect = VibrationEffect.createWaveform(timings, -1)
                            vibrator.vibrate(effect)
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(timings, -1)
                    }
                    result.success(null)
                }
                "hasAmplitudeControl" -> {
                    val hasControl = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.hasAmplitudeControl()
                    } else {
                        false
                    }
                    result.success(hasControl)
                }
                else -> result.notImplemented()
            }
        }
    }
}
