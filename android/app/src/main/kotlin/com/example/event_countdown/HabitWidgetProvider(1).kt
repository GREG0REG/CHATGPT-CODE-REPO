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

        private val DAY_LABEL_IDS = listOf(
            R.id.habit_row_day_0, R.id.habit_row_day_1, R.id.habit_row_day_2,
            R.id.habit_row_day_3, R.id.habit_row_day_4, R.id.habit_row_day_5,
            R.id.habit_row_day_6
        )
        private val DOT_IDS = listOf(
            R.id.habit_row_dot_0, R.id.habit_row_dot_1, R.id.habit_row_dot_2,
            R.id.habit_row_dot_3, R.id.habit_row_dot_4, R.id.habit_row_dot_5,
            R.id.habit_row_dot_6
        )

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val habitCount = widgetData.getInt("habit_count", 0)

                val freshViews = RemoteViews(context.packageName, R.layout.habit_widget_layout)

                if (habitCount <= 0) {
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

                        val rowViews = RemoteViews(context.packageName, R.layout.habit_widget_row)

                        rowViews.setTextViewText(R.id.habit_row_name, habitName)

                        val progressText = "$completed/$target"
                        rowViews.setTextViewText(R.id.habit_row_progress, progressText)

                        val accentColor = try {
                            Color.parseColor(colorStr)
                        } catch (e: Exception) {
                            android.util.Log.w("HabitWidget", "Invalid color: $colorStr, falling back")
                            Color.parseColor("#4CAF50")
                        }

                        rowViews.setTextColor(R.id.habit_row_progress, accentColor)

                        if (streak > 0) {
                            rowViews.setTextViewText(R.id.habit_row_streak, "\uD83D\uDD25 $streak")
                            rowViews.setTextColor(R.id.habit_row_streak, Color.parseColor("#FF9800"))
                            rowViews.setViewVisibility(R.id.habit_row_streak, android.view.View.VISIBLE)
                        } else {
                            rowViews.setViewVisibility(R.id.habit_row_streak, android.view.View.GONE)
                        }

                        for (dayIndex in 0 until DAYS_PER_WEEK) {
                            val dayKey = "habit_day_${i}_$dayIndex"
                            val isDone = widgetData.getBoolean(dayKey, false)
                            val dotId = DOT_IDS[dayIndex]
                            val labelId = DAY_LABEL_IDS[dayIndex]

                            if (isDone) {
                                rowViews.setTextColor(dotId, accentColor)
                            } else {
                                rowViews.setTextColor(dotId, Color.parseColor("#33FFFFFF"))
                            }
                            rowViews.setTextColor(labelId, Color.parseColor("#88FFFFFF"))
                        }

                        freshViews.addView(R.id.habit_widget_container, rowViews)
                    }
                }

                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { openAppIntent ->
                    openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId + 3000, openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    freshViews.setOnClickPendingIntent(R.id.habit_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, freshViews)
                android.util.Log.i("HabitWidget", "Widget $widgetId updated: $habitCount habits")

            } catch (e: Exception) {
                android.util.Log.e("HabitWidget", "Update failed for widget $widgetId", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.habit_widget_layout)
                    fallbackViews.setViewVisibility(R.id.habit_widget_empty, android.view.View.VISIBLE)
                    fallbackViews.setViewVisibility(R.id.habit_widget_container, android.view.View.GONE)
                    fallbackViews.setTextViewText(R.id.habit_widget_empty, "Habit Tracker\nTap to open app")
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (e2: Exception) {
                    android.util.Log.e("HabitWidget", "Fallback also failed", e2)
                }
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
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.i("HabitWidget", "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        android.util.Log.i("HabitWidget", "Widget disabled")
    }
}