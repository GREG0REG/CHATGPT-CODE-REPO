package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONArray

class EventCountdownWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        private const val KEY_PROGRESS = "widget_progress_percent"
        private const val KEY_URGENCY_COLOR = "widget_urgency_color"
        
        // NEW: Grade and Tasks keys
        private const val KEY_GRADE_CURRENT = "grade_current"
        private const val KEY_GRADE_LETTER = "grade_letter"
        private const val KEY_TASKS_DATA = "tasks_data"
        private const val KEY_TASKS_URGENT = "tasks_urgent_count"
        private const val KEY_TASKS_TOTAL = "tasks_total_count"

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            title: String,
            countdown: String,
            bgColorStr: String?,
            textColorStr: String?,
            progressPercent: Int = 65,
            urgencyColorName: String? = null
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                // Set text content
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdown)

                // Update progress bar
                views.setProgressBar(R.id.widget_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Parse theme colors
                val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#00BFA5"))
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)

                // Set background color on the root
                views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)

                // Text colors
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)

                // Urgency indicator - show for orange, deepOrange, red
                val showUrgency = urgencyColorName != null &&
                    urgencyColorName != "green" &&
                    urgencyColorName != "grey"

                if (showUrgency) {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.VISIBLE)
                    val urgencyColor = when (urgencyColorName) {
                        "red" -> Color.parseColor("#F44336")
                        "deepOrange" -> Color.parseColor("#FF5722")
                        "orange" -> Color.parseColor("#FF9800")
                        else -> Color.parseColor("#FF9800")
                    }
                    views.setTextColor(R.id.widget_urgency_dot, urgencyColor)
                    val urgencyLabel = when (urgencyColorName) {
                        "red" -> "URGENT"
                        "deepOrange" -> "Soon"
                        "orange" -> "Upcoming"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, urgencyColor)
                } else {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.GONE)
                }

                // Launch intent - tap anywhere opens app
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Update failed", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val title = prefs.getString(KEY_TITLE, "No upcoming events") ?: "No upcoming events"
            val countdown = prefs.getString(KEY_COUNTDOWN, "") ?: ""
            val bgColorStr = prefs.getString(KEY_BG_COLOR, null)
            val textColorStr = prefs.getString(KEY_TEXT_COLOR, null)
            val progressPercent = prefs.getInt(KEY_PROGRESS, 65)
            val urgencyColorName = prefs.getString(KEY_URGENCY_COLOR, null)

            // NEW: Read grade and tasks data (available for display if needed)
            val gradeCurrent = prefs.getFloat(KEY_GRADE_CURRENT, 0f)
            val gradeLetter = prefs.getString(KEY_GRADE_LETTER, "N/A") ?: "N/A"
            val tasksData = prefs.getString(KEY_TASKS_DATA, "[]") ?: "[]"
            val tasksUrgent = prefs.getInt(KEY_TASKS_URGENT, 0)
            val tasksTotal = prefs.getInt(KEY_TASKS_TOTAL, 0)

            // Log grade/tasks data for debugging
            android.util.Log.d("EventWidget", "Grade: $gradeCurrent ($gradeLetter), Tasks: $tasksUrgent urgent / $tasksTotal total")

            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId, title, countdown, bgColorStr, textColorStr, progressPercent, urgencyColorName)
            }
        } catch (e: Exception) {
            android.util.Log.e("EventWidget", "onUpdate failed", e)
        }
    }
}
