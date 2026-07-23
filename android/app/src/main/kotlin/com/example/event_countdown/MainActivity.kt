package com.example.event_countdown

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
                        val data = EventCountdownWidgetProvider.readWidgetData(this)
                        val deadlineMillis = (data["deadlineMillis"] as? Number)?.toLong()?.takeIf { it > 0 }
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
                "getFilesDir" -> {
                    try {
                        result.success(filesDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("FILES_DIR_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
