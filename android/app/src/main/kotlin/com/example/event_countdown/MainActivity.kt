package com.example.event_countdown

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.d("MainActivity", "Method call received: ${call.method}")
            when (call.method) {
                "updateWidget" -> {
                    try {
                        val intent = Intent(this, EventCountdownWidgetProvider::class.java).apply {
                            action = EventCountdownWidgetProvider.ACTION_WIDGET_UPDATE
                        }
                        sendBroadcast(intent)
                        android.util.Log.d("MainActivity", "Event widget update broadcast sent")
                        result.success("event_updated")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Event widget update failed", e)
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        val intent = Intent(this, PomodoroWidgetProvider::class.java).apply {
                            action = PomodoroWidgetProvider.ACTION_POMODORO_UPDATE
                        }
                        sendBroadcast(intent)
                        android.util.Log.d("MainActivity", "Pomodoro widget update broadcast sent")
                        result.success("pomodoro_updated")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Pomodoro widget update failed", e)
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                else -> {
                    android.util.Log.w("MainActivity", "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
}
