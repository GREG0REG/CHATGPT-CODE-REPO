package com.example.event_countdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
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
        // NEW: Custom action triggered directly from MainActivity method channel.
        const val ACTION_POMODORO_FORCE_UPDATE = "com.example.event_countdown.POMODORO_WIDGET_FORCE_UPDATE"

        private const val ACTIVE_TICK_INTERVAL_MS = 1_000L
        private const val IDLE_TICK_INTERVAL_MS = 10_000L

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
                // CRITICAL: Flutter stores ALL ints as Long. getInt() = ClassCastException.
                val totalDuration = prefs.getLong(KEY_TOTAL_DURATION, (25 * 60).toLong()).toInt()
                val subject = prefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val status = prefs.getString(KEY_STATUS, "Ready") ?: "Ready"
                val sessions = prefs.getLong(KEY_SESSIONS, 0L).toInt()

                val remainingSeconds = calculateRemainingTime(endTime)

                val timerText = when {
                    phase == "idle" -> "Tap to start"
                    phase == "paused" -> {
                        val savedRemaining = prefs.getLong("flutter.pomodoro_remaining_seconds", 0L).toInt()
                        formatTime(savedRemaining)
                    }
                    remainingSeconds <= 0 && endTime != null -> "00:00"
                    else -> formatTime(remainingSeconds)
                }

                val progressPercent = when {
                    phase == "idle" -> 0
                    phase == "paused" -> prefs.getLong("flutter.pomodoro_progress_percent", 0L).toInt()
                    remainingSeconds <= 0 -> 100
                    totalDuration > 0 -> ((totalDuration - remainingSeconds).toFloat() / totalDuration * 100).toInt().coerceIn(0, 100)
                    else -> 0
                }

                android.util.Log.i("PomodoroWidget", "Widget $widgetId: phase=$phase, timer=$timerText, remaining=$remainingSeconds")

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
                        context, widgetId, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("PomodoroWidget", "Widget $widgetId updated")

                val interval = if (phase == "focusing" || phase == "shortBreak" || phase == "longBreak") {
                    ACTIVE_TICK_INTERVAL_MS
                } else {
                    IDLE_TICK_INTERVAL_MS
                }
                scheduleTick(context, interval)

            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Update failed", e)
                scheduleTick(context, IDLE_TICK_INTERVAL_MS)
            }
        }

        fun scheduleTick(context: Context, intervalMillis: Long) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                    action = ACTION_POMODORO_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                val triggerAt = SystemClock.elapsedRealtime() + intervalMillis
                
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    }
                } catch (e: SecurityException) {
                    android.util.Log.w("PomodoroWidget", "Exact alarm not permitted, using fallback")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    } else {
                        alarmManager.set(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            triggerAt,
                            pendingIntent
                        )
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Schedule failed", e)
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

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        android.util.Log.i("PomodoroWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("PomodoroWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_POMODORO_TICK -> updateAllWidgets(context)
            ACTION_POMODORO_FORCE_UPDATE -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAllWidgets(context)
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                // Safety net: if system sends bare update without IDs, update all directly
                if (intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS) == null) {
                    updateAllWidgets(context)
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        cancelAlarm(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelAlarm(context)
    }
    
    private fun cancelAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, PomodoroWidgetProvider::class.java).apply {
                action = ACTION_POMODORO_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            android.util.Log.e("PomodoroWidget", "Cancel alarm failed", e)
        }
    }
}
