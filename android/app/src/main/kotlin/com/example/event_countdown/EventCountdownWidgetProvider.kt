// CHATGPT-CODE-REPO-TEST/android/app/src/main/kotlin/com/example/event_countdown/EventCountdownWidgetProvider.kt
// COMPLETE REPLACEMENT - DEFENSIVE VERSION

package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class EventCountdownWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        private const val KEY_PROGRESS = "widget_progress_percent"
        private const val KEY_URGENCY_COLOR = "widget_urgency_color"
        private const val KEY_ICON_NAME = "widget_icon_name"

        // Urgency color mapping
        private val URGENCY_COLORS = mapOf(
            "green" to Color.parseColor("#4CAF50"),
            "orange" to Color.parseColor("#FF9800"),
            "deepOrange" to Color.parseColor("#FF5722"),
            "red" to Color.parseColor("#F44336"),
            "grey" to Color.parseColor("#9E9E9E")
        )

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        fun getUrgencyColor(colorName: String?): Int {
            return URGENCY_COLORS[colorName] ?: URGENCY_COLORS["green"]!!
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
            urgencyColorName: String? = null,
            iconName: String? = null
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                // Set text content
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdown)

                // Update progress bar (horizontal, safe)
                views.setProgressBar(R.id.widget_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Parse theme colors
                val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#00BFA5"))
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)

                // Set background color on the FrameLayout root
                views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)

                // Text colors
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)

                // Urgency indicator
                if (urgencyColorName != null && urgencyColorName != "green" && urgencyColorName != "grey") {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.VISIBLE)
                    views.setInt(R.id.widget_urgency_dot, "setBackgroundColor", getUrgencyColor(urgencyColorName))
                    val urgencyLabel = when (urgencyColorName) {
                        "red" -> "URGENT"
                        "deepOrange" -> "Soon"
                        "orange" -> "Upcoming"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, getUrgencyColor(urgencyColorName))
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
            val iconName = prefs.getString(KEY_ICON_NAME, null)

            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId, title, countdown, bgColorStr, textColorStr, progressPercent, urgencyColorName, iconName)
            }
        } catch (e: Exception) {
            android.util.Log.e("EventWidget", "onUpdate failed", e)
        }
    }
}

class PomodoroWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SUBJECT = "pomodoro_subject"
        private const val KEY_TIMER = "pomodoro_timer_text"
        private const val KEY_STATUS = "pomodoro_status"
        private const val KEY_BG_COLOR = "pomodoro_bg_color"
        private const val KEY_PROGRESS = "pomodoro_progress_percent"
        private const val KEY_SESSIONS = "pomodoro_completed_sessions"

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
            subject: String,
            timerText: String,
            status: String,
            bgColorStr: String?,
            progressPercent: Int = 45,
            completedSessions: Int = 0
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextViewText(R.id.pomodoro_widget_status, status)

                // Update progress bar (horizontal, safe)
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Mini progress bar
                views.setViewVisibility(R.id.pomodoro_mini_progress, android.view.View.VISIBLE)
                views.setProgressBar(R.id.pomodoro_mini_progress, 100, progressPercent.coerceIn(0, 100), false)

                // Show session chips if sessions completed
                if (completedSessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "[fire] " + completedSessions)
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.GONE)
                }

                val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#00BFA5"))
                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", themeColor)

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Update failed", e)
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

            val subject = prefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
            val timerText = prefs.getString(KEY_TIMER, "Tap to start") ?: "Tap to start"
            val status = prefs.getString(KEY_STATUS, "Focus") ?: "Focus"
            val bgColorStr = prefs.getString(KEY_BG_COLOR, null)
            val progressPercent = prefs.getInt(KEY_PROGRESS, 45)
            val completedSessions = prefs.getInt(KEY_SESSIONS, 0)

            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId, subject, timerText, status, bgColorStr, progressPercent, completedSessions)
            }
        } catch (e: Exception) {
            android.util.Log.e("PomodoroWidget", "onUpdate failed", e)
        }
    }
}
