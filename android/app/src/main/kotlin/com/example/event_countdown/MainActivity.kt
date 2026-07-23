package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    try {
                        val intent = Intent(this, EventCountdownWidgetProvider::class.java).apply {
                            action = EventCountdownWidgetProvider.ACTION_WIDGET_UPDATE
                        }
                        sendBroadcast(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        val intent = Intent(this, PomodoroWidgetProvider::class.java).apply {
                            action = PomodoroWidgetProvider.ACTION_POMODORO_UPDATE
                        }
                        sendBroadcast(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
