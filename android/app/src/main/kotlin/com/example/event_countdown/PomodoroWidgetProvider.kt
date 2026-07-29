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
import android.view.View
import android.widget.RemoteViews

// FIXED: Moved outside companion object — data class cannot be inside companion object
private data class PhaseStyle(
    val phaseColor: Int,
    val bgColor: Int,
    val showDefaultRing: Boolean,
    val showBreakRing: Boolean,
    val showPausedRing: Boolean,
    val phaseLabel: String
)

class PomodoroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PHASE = "flutter.pomodoro_phase"
        private const val KEY_END_TIME = "flutter.pomodoro_end_time_millis"
        private const val KEY_TOTAL_DURATION = "flutter.pomodoro_total_duration_seconds"
        private const val KEY_SUBJECT = "flutter.pomodoro_subject"
        private const val KEY_STATUS = "flutter.pomodoro_status"
        private const val KEY_SESSIONS = "flutter.pomodoro_completed_sessions"
        private const val KEY_DISTRACTION_COUNT = "flutter.pomodoro_distraction_count"
        private const val KEY_TOPIC_TAG = "flutter.pomodoro_topic_tag"
        private const val KEY_NEXT_SUBJECT = "flutter.pomodoro_next_subject"
        private const val KEY_DAILY_MINUTES = "flutter.pomodoro_daily_minutes"
        private const val KEY_DAILY_GOAL = "flutter.pomodoro_daily_goal_minutes"

        const val ACTION_POMODORO_TICK = "com.example.event_countdown.POMODORO_WIDGET_TICK"
        private const val ACTIVE_TICK_INTERVAL_MS = 1_000L
        private const val IDLE_TICK_INTERVAL_MS = 10_000L

        // NEET Exam Date: May 2, 2026
        private const val NEET_EXAM_MILLIS = 1751423400000L

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
                val nextSubject = prefs.getString(KEY_NEXT_SUBJECT, null)
                val dailyMinutes = getIntPref(prefs, KEY_DAILY_MINUTES, 0)
                val dailyGoal = getIntPref(prefs, KEY_DAILY_GOAL, 360)

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

                // Determine phase styling
                val isBreak = phase.equals("shortBreak", ignoreCase = true) ||
                        phase.equals("longBreak", ignoreCase = true)
                val isPaused = phase.equals("paused", ignoreCase = true)
                val isFocusing = phase.equals("focusing", ignoreCase = true)
                val isIdle = phase.equals("idle", ignoreCase = true)

                val style = when {
                    isBreak -> PhaseStyle(
                        Color.parseColor("#00C9A7"),
                        Color.parseColor("#0A2E2A"),
                        false, true, false,
                        if (phase.equals("longBreak", ignoreCase = true)) "Long Break" else "Short Break"
                    )
                    isPaused -> PhaseStyle(
                        Color.parseColor("#FFA726"),
                        Color.parseColor("#2A1F0A"),
                        false, false, true,
                        "Paused"
                    )
                    isFocusing -> PhaseStyle(
                        Color.parseColor("#5B6EF5"),
                        Color.parseColor("#0F0F23"),
                        true, false, false,
                        "Deep Focus"
                    )
                    else -> PhaseStyle(
                        Color.parseColor("#5B6EF5"),
                        Color.parseColor("#0F0F23"),
                        true, false, false,
                        "Ready"
                    )
                }

                android.util.Log.i("PomodoroWidget", "Widget $widgetId: phase=$phase, subject=$subject, timer=$timerText, remaining=$remainingSeconds, progress=$progressPercent")

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                // ── Background ──
                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", style.bgColor)

                // ── NEET Countdown Banner ──
                if (neetDays > 0) {
                    views.setViewVisibility(R.id.neet_banner, View.VISIBLE)
                    views.setTextViewText(R.id.neet_days_text, "$neetDays")
                    views.setTextViewText(R.id.neet_label_text, if (neetDays == 1) "day left" else "days left")
                    val bannerColor = when {
                        neetDays <= 7 -> Color.parseColor("#FF1744")
                        neetDays <= 30 -> Color.parseColor("#FF6B6B")
                        neetDays <= 90 -> Color.parseColor("#FF9800")
                        else -> Color.parseColor("#667EEA")
                    }
                    views.setInt(R.id.neet_banner, "setBackgroundColor", bannerColor)
                } else {
                    views.setViewVisibility(R.id.neet_banner, View.GONE)
                }

                // ── Phase Pill ──
                // FIXED: Use setInt with safe ARGB int, not String.format + Color.parseColor
                if (!isIdle) {
                    views.setViewVisibility(R.id.pomodoro_phase_pill, View.VISIBLE)
                    views.setTextViewText(R.id.pomodoro_phase_pill, style.phaseLabel)
                    views.setTextColor(R.id.pomodoro_phase_pill, style.phaseColor)
                    // Safe alpha blend: (alpha << 24) | (rgb & 0xFFFFFF)
                    val pillBg = (0x15 shl 24) or (style.phaseColor and 0xFFFFFF)
                    views.setInt(R.id.pomodoro_phase_pill, "setBackgroundColor", pillBg)
                } else {
                    views.setViewVisibility(R.id.pomodoro_phase_pill, View.GONE)
                }

                // ── Timer ──
                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextColor(R.id.pomodoro_widget_timer, Color.WHITE)

                // ── Status ──
                val statusText = when {
                    isIdle -> "Tap to begin"
                    isFocusing -> "Session ${sessions + 1}"
                    isBreak -> "${formatTime(remainingSeconds)} remaining"
                    isPaused -> "Tap app to resume"
                    else -> status
                }
                views.setTextViewText(R.id.pomodoro_widget_status, statusText)
                views.setTextColor(R.id.pomodoro_widget_status, Color.parseColor("#B0FFFFFF"))

                // ── Subject ──
                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextColor(R.id.pomodoro_widget_subject, Color.WHITE)

                // ── Topic ──
                if (topicTag != null && topicTag.isNotEmpty()) {
                    views.setViewVisibility(R.id.pomodoro_widget_topic, View.VISIBLE)
                    views.setTextViewText(R.id.pomodoro_widget_topic, "\uD83D\uDCCC $topicTag")
                } else {
                    views.setViewVisibility(R.id.pomodoro_widget_topic, View.GONE)
                }

                // ── Progress Rings ──
                views.setProgressBar(R.id.pomodoro_progress_ring_default, 100, progressPercent, false)
                views.setProgressBar(R.id.pomodoro_progress_ring_break, 100, progressPercent, false)
                views.setProgressBar(R.id.pomodoro_progress_ring_paused, 100, progressPercent, false)

                views.setViewVisibility(R.id.pomodoro_progress_ring_default, if (style.showDefaultRing) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.pomodoro_progress_ring_break, if (style.showBreakRing) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.pomodoro_progress_ring_paused, if (style.showPausedRing) View.VISIBLE else View.GONE)

                // ── Session Counter ──
                if (sessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "$sessions")
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, View.GONE)
                }

                // ── Distraction Counter ──
                if (isFocusing && distractionCount > 0) {
                    views.setViewVisibility(R.id.distraction_chip, View.VISIBLE)
                    views.setTextViewText(R.id.distraction_text, "$distractionCount")
                } else {
                    views.setViewVisibility(R.id.distraction_chip, View.GONE)
                }

                // ── Next Subject Preview (during break) ──
                if (isBreak && nextSubject != null && nextSubject.isNotEmpty()) {
                    views.setViewVisibility(R.id.next_subject_chip, View.VISIBLE)
                    views.setTextViewText(R.id.next_subject_text, "Next: $nextSubject")
                } else {
                    views.setViewVisibility(R.id.next_subject_chip, View.GONE)
                }

                // ── Daily Goal Bar ──
                if (dailyGoal > 0) {
                    views.setViewVisibility(R.id.daily_goal_container, View.VISIBLE)
                    views.setTextViewText(R.id.daily_goal_text, "$dailyMinutes / $dailyGoal min")
                    val goalPercent = ((dailyMinutes.toFloat() / dailyGoal) * 100).toInt().coerceIn(0, 100)
                    views.setProgressBar(R.id.daily_goal_progress, 100, goalPercent, false)
                } else {
                    views.setViewVisibility(R.id.daily_goal_container, View.GONE)
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

                val interval = if (isFocusing || isBreak) {
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
        super.onUpdate(context, appWidgetManager, appWidgetIds)
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
