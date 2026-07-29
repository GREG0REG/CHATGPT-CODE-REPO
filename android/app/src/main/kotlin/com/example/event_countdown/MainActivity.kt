package com.example.event_countdown

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.i("MainActivity", "Method called: ${call.method}")

            when (call.method) {
                "updateWidget" -> {
                    try {
                        EventCountdownWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "EventCountdownWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        PomodoroWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "PomodoroWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "updateAttendanceWidget" -> {
                    try {
                        AttendanceWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "AttendanceWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "updateTimetableWidget" -> {
                    try {
                        TimetableWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "TimetableWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "updateHabitWidget" -> {
                    try {
                        HabitWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "HabitWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "updateReadingWidget" -> {
                    try {
                        ReadingWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "ReadingWidget update failed", e)
                        result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> {
                    android.util.Log.w("MainActivity", "Unhandled method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }
}
