package com.example.event_countdown

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.i("MainActivity", "Method: ${call.method}")
            when (call.method) {
                "updateWidget" -> {
                    try {
                        EventCountdownWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        PomodoroWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updateAttendanceWidget" -> {
                    try {
                        AttendanceWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updateTimetableWidget" -> {
                    try {
                        TimetableWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
                "updateHabitWidget" -> {
                    try {
                        HabitWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
             }  
         }
    }
}
