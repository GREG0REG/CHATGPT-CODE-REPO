package com.example.event_countdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
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
        // NEW NEET keys
        private const val KEY_DISTRACTION_COUNT = "flutter.pomodoro_distraction_count"
        private const val KEY_TOPIC_TAG = "flutter.pomodoro_topic_tag"

        const val ACTION_POMODORO_TICK = "com.example.event_countdown.POMODORO_WIDGET_TICK"
        private const val ACTIVE_TICK_INTERVAL_MS = 1_000L
        private const val IDLE_TICK_INTERVAL_MS = 10_000L

        // NEET Exam Date: May 2, 2026
        private const val NEET_EXAM_MILLIS = 1751423400000L

        // Flutter stores numbers unpredictably as Int or Long. These helpers try both.
        private fun getIntPref(prefs: SharedPreferences, key: String, default: Int): Int {
            return try {
                prefs.getInt(key, default)
            } catch (e: ClassCastException) {
                try {
                    prefs.getLong(key, default.toLong()).toInt()
                } catch (e2: ClassCastException) {
                    default
                }
            }
        }

        private fun getLongPref(prefs: SharedPreferences, key: String, default: Long): Long {
            return try {
                prefs.getLong(key, default)
            } catch (e: ClassCastException) {
                try {
                    prefs.getInt(key, default.toInt()).toLong()
                } catch (e2: ClassCastException) {
                    default
                }
            }
        }

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

        fun calculateNeetDaysRemaining(): Int {
            val now = System.currentTimeMillis()
            val diff = NEET_EXAM_MILLIS - now
            return (diff / (1000 * 60 * 60 * 24)).toInt().coerceAtLeast(0)
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = getLongPref(prefs, KEY_END_TIME, 0L).takeIf { it > 0 }
                val totalDuration = getIntPref(prefs, KEY_TOTAL_DURATION, 90 * 60)
                val subject = prefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val status = prefs.getString(KEY_STATUS, "Ready") ?: "Ready"
                val sessions = getIntPref(prefs, KEY_SESSIONS, 0)
                val topicTag = prefs.getString(KEY_TOPIC_TAG, null)
                val distractionCount = getIntPref(prefs, KEY_DISTRACTION_COUNT, 0)

                val remainingSeconds = calculateRemainingTime(endTime)
                val neetDays = calculateNeetDaysRemaining()

                val timerText = when {
                    phase == "idle" -> "Tap to Start"
                    phase == "paused" -> {
                        val savedRemaining = getIntPref(prefs, "flutter.pomodoro_remaining_seconds", 0)
                        formatTime(savedRemaining)
                    }
                    remainingSeconds <= 0 && endTime != null -> "00:00"
                    else -> formatTime(remainingSeconds)
                }

                val progressPercent = when {
                    phase == "idle" -> 0
                    phase == "paused" -> getIntPref(prefs, "flutter.pomodoro_progress_percent", 0)
                    remainingSeconds <= 0 -> 100
                    totalDuration > 0 -> ((totalDuration - remainingSeconds).toFloat() / totalDuration * 100).toInt().coerceIn(0, 100)
                    else -> 0
                }

                // Determine phase colors and drawables
                val (ringDrawable, phaseColor, bgColor) = when {
                    phase.equals("shortBreak", ignoreCase = true) ||
                    phase.equals("longBreak", ignoreCase = true) -> {
                        Triple(R.drawable.widget_circular_progress_green, Color.parseColor("#00C9A7"), Color.parseColor("#0A2E2A"))
                    }
                    phase.equals("paused", ignoreCase = true) -> {
                        Triple(R.drawable.widget_circular_progress_orange, Color.parseColor("#FFA726"), Color.parseColor("#2A1F0A"))
                    }
                    phase.equals("focusing", ignoreCase = true) -> {
                        Triple(R.drawable.widget_circular_progress_teal, Color.parseColor("#5B6EF5"), Color.parseColor("#0F0F23"))
                    }
                    else -> {
                        Triple(R.drawable.widget_circular_progress, Color.parseColor("#5B6EF5"), Color.parseColor("#0F0F23"))
                    }
                }

                android.util.Log.i("PomodoroWidget", "Widget $widgetId: phase=$phase, subject=$subject, timer=$timerText, remaining=$remainingSeconds, progress=$progressPercent")

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                // ── Apply background color ──
                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", bgColor)

                // ── NEET Countdown Banner ──
                if (neetDays > 0) {
                    views.setViewVisibility(R.id.neet_banner, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.neet_days_text, "$neetDays")
                    views.setTextViewText(R.id.neet_label_text, if (neetDays == 1) "day left" else "days left")
                    val bannerColor = if (neetDays <= 30) Color.parseColor("#FF6B6B") else Color.parseColor("#667EEA")
                    views.setInt(R.id.neet_banner, "setBackgroundColor", bannerColor)
                } else {
                    views.setViewVisibility(R.id.neet_banner, android.view.View.GONE)
                }

                // ── Subject & Topic ──
                val displaySubject = if (topicTag != null) "$subject • $topicTag" else subject
                views.setTextViewText(R.id.pomodoro_widget_subject, displaySubject)
                views.setTextColor(R.id.pomodoro_widget_subject, Color.WHITE)

                // ── Timer (centered in ring) ──
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextColor(R.id.pomodoro_widget_timer, Color.WHITE)

                // ── Status ──
                views.setTextViewText(R.id.pomodoro_widget_status, status)
                views.setTextColor(R.id.pomodoro_widget_status, Color.parseColor("#B0FFFFFF"))

                // ── Circular Progress Ring ──
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent, false)
                // Apply the appropriate drawable based on phase
                views.setInt(R.id.pomodoro_progress_ring, "setProgressDrawable", ringDrawable)

                // ── Session Counter ──
                if (sessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "🔥 $sessions")
                    views.setTextColor(R.id.completed_sessions, Color.parseColor("#FFA726"))
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, android.view.View.GONE)
                }

                // ── Distraction Counter (only during focus) ──
                if (phase.equals("focusing", ignoreCase = true) && distractionCount > 0) {
                    views.setViewVisibility(R.id.distraction_chip, android.view.View.VISIBLE)
                    views.setTextViewText(R.id.distraction_text, "⚡ $distractionCount")
                } else {
                    views.setViewVisibility(R.id.distraction_chip, android.view.View.GONE)
                }

                // ── Tap to open app ──
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("PomodoroWidget", "Widget $widgetId updated successfully")

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

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.i("PomodoroWidget", "onEnabled: scheduling first tick")
        scheduleTick(context, IDLE_TICK_INTERVAL_MS)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        android.util.Log.i("PomodoroWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
        scheduleTick(context, IDLE_TICK_INTERVAL_MS)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("PomodoroWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_POMODORO_TICK -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAllWidgets(context)
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val widgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (widgetIds != null && widgetIds.isNotEmpty()) {
                    for (widgetId in widgetIds) {
                        updateWidgetDirectly(context, AppWidgetManager.getInstance(context), widgetId)
                    }
                } else {
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
