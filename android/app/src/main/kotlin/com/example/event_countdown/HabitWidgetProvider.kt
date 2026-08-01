package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class HabitWidgetProvider : AppWidgetProvider() {

    companion object {
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

            // ── Read data from home_widget SharedPreferences ──
            val widgetData = HomeWidgetPlugin.getData(context)

            val habitCount = widgetData.getInt("habit_count", 0)

            // Safe defaults
            var habitName = "No Habits"
            var weekProgress = 0
            var weekTarget = 7
            var statusColor = "#4CAF50"
            var message = "Add habits to start tracking"

            if (habitCount > 0) {
                // Use the first habit for the widget (top streak)
                habitName = widgetData.getString("habit_name_0", habitName) ?: habitName
                weekProgress = widgetData.getInt("habit_streak_0", 0)
                // Calculate weekly progress from progress percent
                val progressPercent = widgetData.getInt("habit_progress_0", 0)
                weekTarget = 7
                weekProgress = ((progressPercent / 100.0) * weekTarget).toInt().coerceIn(0, weekTarget)
                statusColor = widgetData.getString("habit_color_0", statusColor) ?: statusColor
                message = "$weekProgress/$weekTarget this week"
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

                // Set week circles (7 dots) — use setTextColor on "●" TextViews
                for (i in 0 until 7) {
                    val isDone = i < weekProgress
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
