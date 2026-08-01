package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.example.event_countdown/widget"
        private const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            android.util.Log.i(TAG, "Method called: ${call.method}")

            when (call.method) {
                "updateWidget" -> safeWidgetUpdate(result) {
                    EventCountdownWidgetProvider.updateAllWidgets(this)
                }
                "updatePomodoroWidget" -> safeWidgetUpdate(result) {
                    PomodoroWidgetProvider.updateAllWidgets(this)
                }
                "updateAttendanceWidget" -> safeWidgetUpdate(result) {
                    AttendanceWidgetProvider.updateAllWidgets(this)
                }
                "updateTimetableWidget" -> safeWidgetUpdate(result) {
                    TimetableWidgetProvider.updateAllWidgets(this)
                }
                "updateHabitWidget" -> safeWidgetUpdate(result) {
                    HabitWidgetProvider.updateAllWidgets(this)
                }
                "updateReadingWidget" -> safeWidgetUpdate(result) {
                    ReadingWidgetProvider.updateAllWidgets(this)
                }
                "getWidgetIds" -> {
                    try {
                        val widgetType = call.argument<String>("widgetType") ?: ""
                        val componentName = when (widgetType) {
                            "event" -> ComponentName(this, EventCountdownWidgetProvider::class.java)
                            "pomodoro" -> ComponentName(this, PomodoroWidgetProvider::class.java)
                            "attendance" -> ComponentName(this, AttendanceWidgetProvider::class.java)
                            "timetable" -> ComponentName(this, TimetableWidgetProvider::class.java)
                            "habit" -> ComponentName(this, HabitWidgetProvider::class.java)
                            "reading" -> ComponentName(this, ReadingWidgetProvider::class.java)
                            else -> null
                        }
                        val ids = if (componentName != null) {
                            AppWidgetManager.getInstance(this).getAppWidgetIds(componentName)
                        } else {
                            intArrayOf()
                        }
                        result.success(ids.toList())
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "getWidgetIds failed", e)
                        result.error("WIDGET_ERROR", e.message, null)
                    }
                }
                else -> {
                    android.util.Log.w(TAG, "Unhandled method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private inline fun safeWidgetUpdate(result: io.flutter.plugin.common.MethodChannel.Result, update: () -> Unit) {
        try {
            update()
            result.success("ok")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Widget update failed: ${e.message}", e)
            result.error("WIDGET_ERROR", e.message, e.stackTraceToString())
        }
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return

        val route = intent.getStringExtra("route")
        val screen = intent.getStringExtra("screen")

        if (route != null || screen != null) {
            android.util.Log.i(TAG, "Launched from widget: route=$route, screen=$screen")
            // The Flutter app should listen for these via MethodChannel or initial route
            // This data is available when the app starts from a widget tap
        }
    }
}