package com.cazstudio.edutranslate_ai

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "openVoiceInputSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                startActivity(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))
                result.success(true)
            } catch (_: Exception) {
                try {
                    startActivity(Intent(Settings.ACTION_SETTINGS))
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
        }
    }

    private companion object {
        const val VOICE_SETTINGS_CHANNEL =
            "com.cazstudio.edutranslate_ai/voice_settings"
    }
}
