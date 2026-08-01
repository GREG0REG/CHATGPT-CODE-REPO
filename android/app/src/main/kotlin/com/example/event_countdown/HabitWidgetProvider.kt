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
        private const val MAX_HABITS = 7
        private const val DAYS_PER_WEEK = 7

        // Day label IDs in the row template (M, T, W, T, F, S, S)
        private val DAY_LABEL_IDS = listOf(
            R.id.habit_row_day_0,
            R.id.habit_row_day_1,
            R.id.habit_row_day_2,
            R.id.habit_row_day_3,
            R.id.habit_row_day_4,
            R.id.habit_row_day_5,
            R.id.habit_row_day_6
        )

        // Dot IDs in the row template
        private val DOT_IDS = listOf(
            R.id.habit_row_dot_0,
            R.id.habit_row_dot_1,
            R.id.habit_row_dot_2,
            R.id.habit_row_dot_3,
            R.id.habit_row_dot_4,
            R.id.habit_row_dot_5,
            R.id.habit_row_dot_6
        )

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.habit_widget_layout)
            val widgetData = HomeWidgetPlugin.getData(context)

            val habitCount = widgetData.getInt("habit_count", 0)

            // Clear any previously added rows by re-inflating the base layout
            // (RemoteViews doesn't support removing views, so we rebuild)
            val freshViews = RemoteViews(context.packageName, R.layout.habit_widget_layout)

            if (habitCount <= 0) {
                // No habits — show empty state
                freshViews.setViewVisibility(R.id.habit_widget_empty, android.view.View.VISIBLE)
                freshViews.setViewVisibility(R.id.habit_widget_container, android.view.View.GONE)
            } else {
                freshViews.setViewVisibility(R.id.habit_widget_empty, android.view.View.GONE)
                freshViews.setViewVisibility(R.id.habit_widget_container, android.view.View.VISIBLE)

                val displayCount = habitCount.coerceAtMost(MAX_HABITS)

                for (i in 0 until displayCount) {
                    val habitName = widgetData.getString("habit_name_$i", "Habit") ?: "Habit"
                    val streak = widgetData.getInt("habit_streak_$i", 0)
                    val progress = widgetData.getInt("habit_progress_$i", 0)
                    val completed = widgetData.getInt("habit_completed_$i", 0)
                    val target = widgetData.getInt("habit_target_$i", 7)
                    val colorStr = widgetData.getString("habit_color_$i", "#4CAF50") ?: "#4CAF50"

                    // Inflate row template
                    val rowViews = RemoteViews(context.packageName, R.layout.habit_widget_row)

                    // Habit name
                    rowViews.setTextViewText(R.id.habit_row_name, habitName)

                    // Streak + progress text
                    val progressText = "$completed/$target"
                    rowViews.setTextViewText(R.id.habit_row_progress, progressText)

                    // Parse accent color
                    val accentColor = try {
                        Color.parseColor(colorStr)
                    } catch (e: Exception) {
                        android.util.Log.w("HabitWidget", "Invalid color: $colorStr, falling back")
                        Color.parseColor("#4CAF50")
                    }

                    // Color the progress text
                    rowViews.setTextColor(R.id.habit_row_progress, accentColor)

                    // Streak fire icon (show if streak > 0)
                    if (streak > 0) {
                        rowViews.setTextViewText(R.id.habit_row_streak, "🔥 $streak")
                        rowViews.setTextColor(R.id.habit_row_streak, Color.parseColor("#FF9800"))
                        rowViews.setViewVisibility(R.id.habit_row_streak, android.view.View.VISIBLE)
                    } else {
                        rowViews.setViewVisibility(R.id.habit_row_streak, android.view.View.GONE)
                    }

                    // Set day dots — read per-day completion from SharedPreferences
                    // Keys: habit_day_0_0 = habit 0, Monday; habit_day_0_6 = habit 0, Sunday
                    for (dayIndex in 0 until DAYS_PER_WEEK) {
                        val dayKey = "habit_day_${i}_$dayIndex"
                        val isDone = widgetData.getBoolean(dayKey, false)
                        val dotId = DOT_IDS[dayIndex]
                        val labelId = DAY_LABEL_IDS[dayIndex]

                        // Set dot color: accent if done, faint if not
                        if (isDone) {
                            rowViews.setTextColor(dotId, accentColor)
                        } else {
                            rowViews.setTextColor(dotId, Color.parseColor("#33FFFFFF"))
                        }

                        // Day label color: slightly brighter for today
                        rowViews.setTextColor(labelId, Color.parseColor("#88FFFFFF"))
                    }

                    // Add row to container
                    freshViews.addView(R.id.habit_widget_container, rowViews)
                }
            }

            // Tap opens app (on entire widget)
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { openAppIntent ->
                openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId + 3000,
                    openAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                freshViews.setOnClickPendingIntent(R.id.habit_widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, freshViews)
            android.util.Log.i("HabitWidget", "Widget $widgetId updated: $habitCount habits")
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
