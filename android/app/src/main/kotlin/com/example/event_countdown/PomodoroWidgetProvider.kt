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

class PomodoroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PHASE = "flutter.pomodoro_phase"
        private const val KEY_END_TIME = "flutter.pomodoro_end_time_millis"
        private const val KEY_TOTAL_DURATION = "flutter.pomodoro_total_duration_seconds"
        private const val KEY_SUBJECT = "flutter.pomodoro_subject"
        private const val KEY_STATUS = "flutter.pomodoro_status"
        private const val KEY_SESSIONS = "flutter.pomodoro_completed_sessions"

        const val ACTION_POMODORO_TICK = "com.example.event_countdown.POMODORO_WIDGET_TICK"

        fun calculateRemainingTime(endTimeMillis: Long?): Int {
            if (endTimeMillis == null || endTimeMillis <= 0) return 0
            val now = System.currentTimeMillis()
            val remaining = ((endTimeMillis - now) / 1000).toInt()
            return remaining.coerceAtLeast(0)
        }

        fun formatTime(seconds: Int): String {
            val m = (seconds / 60).toString().padStart(2, '0')
            val s = (seconds % 60).toString().padStart(2, '0')
            return "$m:$s"
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = prefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }
                val totalDuration = prefs.getInt(KEY_TOTAL_DURATION, 25 * 60)
                val subject = prefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val status = prefs.getString(KEY_STATUS, "Ready") ?: "Ready"
                val sessions = prefs.getInt(KEY_SESSIONS, 0)

                val remainingSeconds = calculateRemainingTime(endTime)

                val timerText = when {
                    phase == "idle" -> "Tap to start"
                    phase == "paused" -> {
                        val savedRemaining = prefs.getInt("flutter.pomodoro_remaining_seconds", 0)
                        formatTime(savedRemaining)
                    }
                    remainingSeconds <= 0 && endTime != null -> "00:00"
                    else -> formatTime(remainingSeconds)
                }

                val progressPercent = when {
                    phase == "idle" -> 0
                    phase == "paused" -> {
                        val savedProgress = prefs.getInt("flutter.pomodoro_progress_percent", 0)
                        savedProgress
                    }
                    remainingSeconds <= 0 -> 100
                    totalDuration > 0 -> ((totalDuration - remainingSeconds).toFloat() / totalDuration * 100).toInt().coerceIn(0, 100)
                    else -> 0
                }

                android.util.Log.i("PomodoroWidget", "UPDATE: phase=$phase, remaining=$remainingSeconds, timer=$timerText")

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextViewText(R.id.pomodoro_widget_status, status)
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent, false)

                val themeColor = when {
                    phase.equals("shortBreak", ignoreCase = true) ||
                    phase.equals("longBreak", ignoreCase = true) -> Color.parseColor("#00BFA5")
                    phase.equals("paused", ignoreCase = true) -> Color.parseColor("#FFA726")
                    else -> Color.parseColor("#FF6B6B")
                }

                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", themeColor)
                views.setTextColor(R.id.pomodoro_widget_subject, Color.WHITE)
                views.setTextColor(R.id.pomodoro_widget_timer, Color.WHITE)
                views.setTextColor(R.id.pomodoro_widget_status, Color.WHITE)

                if (sessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "\uD83D\uDD25 $sessions")
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.GONE)
                }

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("PomodoroWidget", "Widget $widgetId updated: $timerText | $status")

                if ((phase == "focusing" || phase == "shortBreak" || phase == "longBreak") && remainingSeconds > 0) {
                    scheduleTick(context)
                }

            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Update failed", e)
            }
        }

        fun scheduleTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                    action = ACTION_POMODORO_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                val triggerTime = SystemClock.elapsedRealtime() + 1000
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Failed to schedule tick", e)
            }
        }

        fun cancelTicks(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                    action = ACTION_POMODORO_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Failed to cancel ticks", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PomodoroWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("PomodoroWidget", "Updating ${widgetIds.size} widgets")
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
        android.util.Log.i("PomodoroWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("PomodoroWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_POMODORO_TICK -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = prefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }
                val remaining = calculateRemainingTime(endTime)

                updateAllWidgets(context)

                if ((phase == "focusing" || phase == "shortBreak" || phase == "longBreak") && remaining > 0) {
                    scheduleTick(context)
                } else {
                    cancelTicks(context)
                }
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = prefs.getLong(KEY_END_TIME, 0L).takeIf { it > 0 }

                if (phase != "idle" && endTime != null) {
                    val remaining = calculateRemainingTime(endTime)
                    if (remaining > 0) {
                        updateAllWidgets(context)
                        scheduleTick(context)
                    }
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        cancelTicks(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelTicks(context)
    }
}
