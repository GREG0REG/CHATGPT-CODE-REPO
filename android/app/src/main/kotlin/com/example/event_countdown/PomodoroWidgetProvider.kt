package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews

class PomodoroWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SUBJECT = "pomodoro_subject"
        private const val KEY_TIMER = "pomodoro_timer_text"
        private const val KEY_STATUS = "pomodoro_status"
        private const val KEY_BG_COLOR = "pomodoro_bg_color"
        private const val KEY_PROGRESS = "pomodoro_progress_percent"
        private const val KEY_SESSIONS = "pomodoro_completed_sessions"

        // Default coral/red color matching the screenshot
        private const val DEFAULT_CORAL = "#FF6B6B"
        private const val DEFAULT_TEAL = "#00BFA5"

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

                // Set text content
                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextViewText(R.id.pomodoro_widget_status, status)

                // Update progress bar
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Parse theme colors - use coral/red for focus, teal for break
                val isFocusMode = status.equals("Focus", ignoreCase = true) || 
                                  status.equals("Focusing", ignoreCase = true) ||
                                  status.equals("Ready to Focus", ignoreCase = true)
                
                val themeColor = if (isFocusMode) {
                    parseColorOrDefault(bgColorStr, Color.parseColor(DEFAULT_CORAL))
                } else {
                    parseColorOrDefault(bgColorStr, Color.parseColor(DEFAULT_TEAL))
                }
                
                // Set background color on the root
                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", themeColor)

                // Text colors - always white for contrast
                views.setTextColor(R.id.pomodoro_widget_subject, Color.WHITE)
                views.setTextColor(R.id.pomodoro_widget_timer, Color.WHITE)
                views.setTextColor(R.id.pomodoro_widget_status, Color.WHITE)

                // Show session chips if sessions completed
                if (completedSessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "\uD83D\uDD25 $completedSessions")
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.GONE)
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
