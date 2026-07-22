package com.example.event_countdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.SystemClock
import android.widget.RemoteViews

/**
 * Pomodoro Widget Provider with LIVE timer support.
 * Calculates remaining time from persisted end-time, so widget stays accurate
 * even when the app is killed, screen is off, or device is in Doze mode.
 */
class PomodoroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PHASE = "pomodoro_phase"
        private const val KEY_END_TIME = "pomodoro_end_time_millis"
        private const val KEY_TOTAL_DURATION = "pomodoro_total_duration_seconds"
        private const val KEY_SUBJECT = "pomodoro_subject"
        private const val KEY_STATUS = "pomodoro_status"
        private const val KEY_BG_COLOR = "pomodoro_bg_color"
        private const val KEY_SESSIONS = "pomodoro_completed_sessions"

        // Default colors
        private const val DEFAULT_CORAL = "#FF6B6B"
        private const val DEFAULT_TEAL = "#00BFA5"
        private const val DEFAULT_AMBER = "#FFA726"

        // Alarm action for widget updates
        const val ACTION_WIDGET_UPDATE = "com.example.event_countdown.WIDGET_UPDATE"
        const val ACTION_WIDGET_TICK = "com.example.event_countdown.WIDGET_TICK"

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        /**
         * Calculate remaining time from end-time for LIVE updates.
         * This is the KEY function that makes the widget work independently.
         */
        fun calculateRemainingTime(endTimeMillis: Long?): Int {
            if (endTimeMillis == null) return 0
            val now = System.currentTimeMillis()
            val remaining = ((endTimeMillis - now) / 1000).toInt()
            return remaining.coerceAtLeast(0)
        }

        /**
         * Format seconds as MM:SS
         */
        fun formatTime(seconds: Int): String {
            val m = (seconds / 60).toString().padStart(2, '0')
            val s = (seconds % 60).toString().padStart(2, '0')
            return "$m:$s"
        }

        /**
         * Calculate progress percentage from remaining time and total duration
         */
        fun calculateProgress(remainingSeconds: Int, totalDurationSeconds: Int): Int {
            if (totalDurationSeconds <= 0) return 0
            val elapsed = totalDurationSeconds - remainingSeconds
            return ((elapsed.toFloat() / totalDurationSeconds) * 100).toInt().coerceIn(0, 100)
        }

        /**
         * Determine theme color based on phase
         */
        fun getThemeColor(phase: String?, bgColorStr: String?): Int {
            val isFocusMode = phase.equals("focusing", ignoreCase = true) ||
                              phase.equals("focus", ignoreCase = true) ||
                              phase.equals("ready to focus", ignoreCase = true) ||
                              phase.equals("idle", ignoreCase = true) ||
                              phase.equals("paused", ignoreCase = true)

            val isBreakMode = phase.equals("shortBreak", ignoreCase = true) ||
                              phase.equals("longBreak", ignoreCase = true) ||
                              phase.equals("short break", ignoreCase = true) ||
                              phase.equals("long break", ignoreCase = true)

            return when {
                isFocusMode -> parseColorOrDefault(bgColorStr, Color.parseColor(DEFAULT_CORAL))
                isBreakMode -> parseColorOrDefault(bgColorStr, Color.parseColor(DEFAULT_TEAL))
                else -> parseColorOrDefault(bgColorStr, Color.parseColor(DEFAULT_CORAL))
            }
        }

        /**
         * Main widget update function - reads LIVE state and updates UI
         */
        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            prefs: android.content.SharedPreferences? = null
        ) {
            try {
                val sharedPrefs = prefs ?: context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val phase = sharedPrefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTimeMillis = sharedPrefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }
                val totalDuration = sharedPrefs.getInt(KEY_TOTAL_DURATION, 25 * 60)
                val subject = sharedPrefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val status = sharedPrefs.getString(KEY_STATUS, "Focus") ?: "Focus"
                val bgColorStr = sharedPrefs.getString(KEY_BG_COLOR, null)
                val completedSessions = sharedPrefs.getInt(KEY_SESSIONS, 0)

                // LIVE calculation: compute remaining time from end-time
                val remainingSeconds = calculateRemainingTime(endTimeMillis)
                val timerText = if (phase == "idle") {
                    "Tap to start"
                } else if (phase == "paused") {
                    val savedRemaining = sharedPrefs.getInt("pomodoro_remaining_seconds", 0)
                    formatTime(savedRemaining)
                } else {
                    formatTime(remainingSeconds)
                }

                // LIVE progress calculation
                val progressPercent = if (phase == "idle" || phase == "paused") {
                    sharedPrefs.getInt("pomodoro_progress_percent", 45)
                } else {
                    calculateProgress(remainingSeconds, totalDuration)
                }

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                // Set text content
                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextViewText(R.id.pomodoro_widget_status, status)

                // Update progress bar with LIVE value
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent, false)

                // Theme colors based on phase
                val themeColor = getThemeColor(phase, bgColorStr)
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

                // Launch intent - tap anywhere opens app to Pomodoro screen
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("route", "/pomodoro")
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)

                // If timer is active, schedule next update
                if (phase != "idle" && phase != "paused" && remainingSeconds > 0) {
                    scheduleWidgetUpdate(context)
                }

            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Update failed", e)
            }
        }

        /**
         * Schedule a precise alarm to update the widget every second while timer is active.
         * Uses AlarmManager for reliability even in Doze mode.
         */
        fun scheduleWidgetUpdate(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // Cancel any existing alarm first
                alarmManager.cancel(pendingIntent)

                // Schedule next update in 1 second using exact alarm
                val triggerTime = SystemClock.elapsedRealtime() + 1000
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Failed to schedule update", e)
            }
        }

        /**
         * Cancel all scheduled widget updates
         */
        fun cancelWidgetUpdates(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Failed to cancel updates", e)
            }
        }

        /**
         * Update all active widgets
         */
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PomodoroWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            for (widgetId in widgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId, prefs)
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

            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId, prefs)
            }
        } catch (e: Exception) {
            android.util.Log.e("PomodoroWidget", "onUpdate failed", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_WIDGET_TICK -> {
                // Alarm fired - update widget with LIVE time
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTimeMillis = prefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }
                val remainingSeconds = calculateRemainingTime(endTimeMillis)

                // Update all widgets
                updateAllWidgets(context)

                // Schedule next tick if timer still active
                if (phase != "idle" && phase != "paused" && remainingSeconds > 0) {
                    scheduleWidgetUpdate(context)
                } else if (remainingSeconds <= 0 && phase != "idle") {
                    // Timer finished - cancel updates
                    cancelWidgetUpdates(context)
                }
            }
            ACTION_WIDGET_UPDATE -> {
                // Explicit update request (from app)
                updateAllWidgets(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                // Device rebooted - restore widget if timer was active
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTimeMillis = prefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }

                if (phase != "idle" && endTimeMillis != null) {
                    val remaining = calculateRemainingTime(endTimeMillis)
                    if (remaining > 0) {
                        // Timer still running after reboot - resume updates
                        updateAllWidgets(context)
                        scheduleWidgetUpdate(context)
                    }
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // Cancel alarms when widget is removed
        cancelWidgetUpdates(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Cancel all alarms when last widget is removed
        cancelWidgetUpdates(context)
    }
}
