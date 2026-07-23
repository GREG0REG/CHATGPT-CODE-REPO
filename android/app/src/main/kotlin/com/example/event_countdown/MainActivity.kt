package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
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
                        EventCountdownWidgetProvider.updateAllWidgets(this)
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val deadlineMillis = prefs.getLong("flutter.widget_event_deadline_millis", 0L).takeIf { it > 0 }
                        if (deadlineMillis != null && deadlineMillis > System.currentTimeMillis()) {
                            EventCountdownWidgetProvider.scheduleWidgetTick(this)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        PomodoroWidgetProvider.updateAllWidgets(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
