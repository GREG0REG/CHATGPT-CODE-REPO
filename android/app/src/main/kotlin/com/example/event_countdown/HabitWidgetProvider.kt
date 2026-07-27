package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class HabitWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val HABIT_DATA_FILE = "habit_widget_data.json"

        private val DOT_IDS = listOf(
            R.id.habit_dot_1,
            R.id.habit_dot_2,
            R.id.habit_dot_3,
            R.id.habit_dot_4,
            R.id.habit_dot_5,
            R.id.habit_dot_6,
            R.id.habit_dot_7
        )

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.habit_widget_layout)

                // Read JSON data written by Flutter
                var habitName = "No Habits"
                var weekProgress = 0
                var weekTarget = 0
                var statusColor = "#4CAF50"
                var message = "Add habits to start tracking"
                val weekCompletion = mutableListOf<Boolean>()

                try {
                    // CRITICAL FIX: Use getApplicationSupportDirectory path
                    val dir = context.getDir("flutter", Context.MODE_PRIVATE)
                    val file = File(dir.parentFile, "app_flutter/habit_widget_data.json")
                    
                    // Fallback to filesDir for compatibility
                    val fallbackFile = File(context.filesDir, HABIT_DATA_FILE)
                    
                    val targetFile = if (file.exists()) file else fallbackFile

                    if (targetFile.exists()) {
                        val json = JSONObject(targetFile.readText())
                        habitName = json.optString("habitName", habitName)
                        weekProgress = json.optInt("weekProgress", 0)
                        weekTarget = json.optInt("weekTarget",                         weekTarget = json.optInt("weekTarget", 7)
                        statusColor = json.optString("colorHex", "#4CAF50")
                        message = json.optString("message", message)

                        // Read week circles if present
                        val circlesArray = json.optJSONArray("weekCircles")
                        if (circlesArray != null) {
                            for (i in 0 until circlesArray.length().coerceAtMost(7)) {
                                weekCompletion.add(circlesArray.getBoolean(i))
                            }
                        }
                    } else {
                        android.util.Log.w("HabitWidget", "Data file not found at: ${targetFile.absolutePath}")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("HabitWidget", "JSON read failed", e)
                }

                // Set habit name and progress text
                views.setTextViewText(R.id.habit_widget_name, habitName)
                views.setTextViewText(R.id.habit_widget_progress, "$weekProgress/$weekTarget")

                // Parse accent color
                val accentColor = try {
                    Color.parseColor(statusColor)
                } catch (e: Exception) {
                    Color.parseColor("#4CAF50")
                }

                // Color the progress text
                views.setTextColor(R.id.habit_widget_progress, accentColor)

                // Set week circles
                for (i in 0 until 7) {
                    val isDone = i < weekCompletion.size && weekCompletion[i]
                    val dotId = DOT_IDS[i]

                    if (isDone) {
                        views.setInt(dotId, "setBackgroundColor", accentColor)
                    } else {
                        views.setInt(dotId, "setBackgroundColor", Color.parseColor("#33FFFFFF"))
                    }
                }

                // Tap opens app
                val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                openAppIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    widgetId + 3000,
                    openAppIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.habit_widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("HabitWidget", "Widget $widgetId updated: $habitName ($weekProgress/$weekTarget)")

            } catch (e: Exception) {
                android.util.Log.e("HabitWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, HabitWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("HabitWidget", "Updating ${widgetIds.size} widgets")
            for (widgetId in widgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.i("HabitWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("HabitWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val widgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (widgetIds != null && widgetIds.isNotEmpty()) {
                    val manager = AppWidgetManager.getInstance(context)
                    for (widgetId in widgetIds) {
                        updateWidgetDirectly(context, manager, widgetId)
                    }
                } else {
                    updateAllWidgets(context)
                }
            }
        }
    }
}
