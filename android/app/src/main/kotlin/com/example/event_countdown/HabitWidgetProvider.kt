package com.example.event_countdown

import android.app.PendingIntent
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
            val views = RemoteViews(context.packageName, R.layout.habit_widget_layout)

            // Safe defaults
            var habitName = "No Habits"
            var weekProgress = 0
            var weekTarget = 7
            var statusColor = "#4CAF50"
            var message = "Add habits to start tracking"
            val weekCompletion = mutableListOf<Boolean>()

            // ── Read JSON data written by Flutter ──
            try {
                // CRITICAL FIX: Use context.filesDir directly — matches Event widget
                val file = File(context.filesDir, HABIT_DATA_FILE)

                if (file.exists()) {
                    val json = JSONObject(file.readText())
                    habitName = json.optString("habitName", habitName)
                    weekProgress = json.optInt("weekProgress", 0)
                    weekTarget = json.optInt("weekTarget", 7)
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
                    android.util.Log.w("HabitWidget", "Data file not found at: ${file.absolutePath}")
                }
            } catch (e: Exception) {
                android.util.Log.e("HabitWidget", "JSON read failed", e)
            }

            // ── Update widget UI ──
            try {
                // Habit name and progress text
                views.setTextViewText(R.id.habit_widget_name, habitName)
                views.setTextViewText(R.id.habit_widget_progress, "$weekProgress/$weekTarget")

                // Parse accent color with safe fallback
                val accentColor = try {
                    Color.parseColor(statusColor)
                } catch (e: Exception) {
                    android.util.Log.w("HabitWidget", "Invalid color: $statusColor, falling back to green")
                    Color.parseColor("#4CAF50")
                }

                // Color the progress text
                views.setTextColor(R.id.habit_widget_progress, accentColor)

                // Set week circles (7 dots) — FIXED: Use setTextColor on "●" TextViews
                for (i in 0 until 7) {
                    val isDone = i < weekCompletion.size && weekCompletion[i]
                    val dotId = DOT_IDS[i]

                    views.setTextViewText(dotId, "●")
                    if (isDone) {
                        views.setTextColor(dotId, accentColor)
                    } else {
                        views.setTextColor(dotId, Color.parseColor("#33FFFFFF"))
                    }
                }

                // Tap opens app
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { openAppIntent ->
                    openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId + 3000,
                        openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.habit_widget_root, pendingIntent)
                }

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
