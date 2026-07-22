package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity with MethodChannel handlers for widget updates.
 * Handles communication from Flutter to update widgets and schedule alarms.
 */
class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    // Update the event countdown widget
                    updateEventWidget()
                    result.success(null)
                }
                "updatePomodoroWidget" -> {
                    // Update the pomodoro widget and schedule live updates
                    updatePomodoroWidget(call)
                    result.success(null)
                }
                "cancelPomodoroWidgetUpdates" -> {
                    // Cancel all scheduled widget updates
                    PomodoroWidgetProvider.cancelWidgetUpdates(context)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun updateEventWidget() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, EventCountdownWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)

            for (widgetId in widgetIds) {
                // Trigger onUpdate for each widget
                val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
                }
                context.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to update event widget", e)
        }
    }

    private fun updatePomodoroWidget(call: io.flutter.plugin.common.MethodCall) {
        try {
            val phase = call.argument<String>("phase") ?: "idle"
            val endTimeMillis = call.argument<Int>("endTimeMillis")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PomodoroWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)

            // Update all pomodoro widgets
            for (widgetId in widgetIds) {
                PomodoroWidgetProvider.updateWidgetDirectly(
                    context,
                    appWidgetManager,
                    widgetId
                )
            }

            // Schedule live updates if timer is active
            if (phase != "idle" && phase != "paused" && endTimeMillis != null) {
                PomodoroWidgetProvider.scheduleWidgetUpdate(context)
            } else if (phase == "idle" || phase == "paused") {
                PomodoroWidgetProvider.cancelWidgetUpdates(context)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to update pomodoro widget", e)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Check if app was opened from widget tap with a specific route
        val route = intent.getStringExtra("route")
        if (route != null) {
            // Store route for Flutter to read
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putString("initial_route", route).apply()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val route = intent.getStringExtra("route")
        if (route != null) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putString("initial_route", route).apply()
        }
    }
}
