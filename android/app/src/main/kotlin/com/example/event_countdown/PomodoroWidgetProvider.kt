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
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PomodoroWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val KEY_PHASE = "pomodoro_phase"
        private const val KEY_TIMER_TEXT = "pomodoro_timer_text"
        private const val KEY_STATUS = "pomodoro_status"
        private const val KEY_SUBJECT = "pomodoro_subject"
        private const val KEY_TOPIC = "pomodoro_topic"
        private const val KEY_PROGRESS = "pomodoro_progress_percent"
        private const val KEY_SESSIONS = "pomodoro_sessions"
        private const val KEY_DISTRACTIONS = "pomodoro_distractions"
        private const val KEY_DAILY_MINUTES = "pomodoro_daily_minutes"
        private const val KEY_DAILY_GOAL = "pomodoro_daily_goal"
        private const val KEY_NEET_DAYS = "pomodoro_neet_days"
        private const val KEY_NEXT_SUBJECT = "pomodoro_next_subject"

        const val ACTION_POMODORO_TICK = "com.example.event_countdown.POMODORO_WIDGET_TICK"
        private const val ACTIVE_TICK_INTERVAL_MS = 1_000L
        private const val IDLE_TICK_INTERVAL_MS = 10_000L

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)

                val phase = widgetData.getString(KEY_PHASE, "idle") ?: "idle"
                val timerText = widgetData.getString(KEY_TIMER_TEXT, "Tap to Start") ?: "Tap to Start"
                val status = widgetData.getString(KEY_STATUS, "Ready") ?: "Ready"
                val subject = widgetData.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val topic = widgetData.getString(KEY_TOPIC, null)
                val progress = widgetData.getInt(KEY_PROGRESS, 0)
                val sessions = widgetData.getInt(KEY_SESSIONS, 0)
                val distractions = widgetData.getInt(KEY_DISTRACTIONS, 0)
                val dailyMinutes = widgetData.getInt(KEY_DAILY_MINUTES, 0)
                val dailyGoal = widgetData.getInt(KEY_DAILY_GOAL, 360)
                val neetDays = widgetData.getInt(KEY_NEET_DAYS, 0)
                val nextSubject = widgetData.getString(KEY_NEXT_SUBJECT, null)

                val isBreak = phase.equals("shortBreak", ignoreCase = true) ||
                        phase.equals("longBreak", ignoreCase = true)
                val isPaused = phase.equals("paused", ignoreCase = true)
                val isFocusing = phase.equals("focusing", ignoreCase = true)
                val isIdle = phase.equals("idle", ignoreCase = true)

                android.util.Log.i("PomodoroWidget", "Widget $widgetId: phase=$phase, timer=$timerText")

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                val bgColor = when {
                    isBreak -> Color.parseColor("#0A2E2A")
                    isPaused -> Color.parseColor("#2A1F0A")
                    else -> Color.parseColor("#0F0F23")
                }
                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", bgColor)

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

                if (!isIdle) {
                    views.setViewVisibility(R.id.pomodoro_phase_pill, View.VISIBLE)
                    val phaseLabel = when {
                        isBreak -> if (phase.equals("longBreak", ignoreCase = true)) "Long Break" else "Short Break"
                        isPaused -> "Paused"
                        isFocusing -> "Deep Focus"
                        else -> "Ready"
                    }
                    val phaseColor = when {
                        isBreak -> Color.parseColor("#00C9A7")
                        isPaused -> Color.parseColor("#FFA726")
                        isFocusing -> Color.parseColor("#5B6EF5")
                        else -> Color.parseColor("#5B6EF5")
                    }
                    views.setTextViewText(R.id.pomodoro_phase_pill, phaseLabel)
                    views.setTextColor(R.id.pomodoro_phase_pill, phaseColor)
                    val pillBg = (0x15 shl 24) or (phaseColor and 0xFFFFFF)
                    views.setInt(R.id.pomodoro_phase_pill, "setBackgroundColor", pillBg)
                } else {
                    views.setViewVisibility(R.id.pomodoro_phase_pill, View.GONE)
                }

                views.setTextViewText(R.id.pomodoro_widget_timer, timerText)
                views.setTextColor(R.id.pomodoro_widget_timer, Color.WHITE)

                val statusText = when {
                    isIdle -> "Tap to begin"
                    isFocusing -> "Session ${sessions + 1}"
                    isBreak -> "$timerText remaining"
                    isPaused -> "Tap app to resume"
                    else -> status
                }
                views.setTextViewText(R.id.pomodoro_widget_status, statusText)
                views.setTextColor(R.id.pomodoro_widget_status, Color.parseColor("#B0FFFFFF"))

                views.setTextViewText(R.id.pomodoro_widget_subject, subject)
                views.setTextColor(R.id.pomodoro_widget_subject, Color.WHITE)

                if (!topic.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.pomodoro_widget_topic, View.VISIBLE)
                    views.setTextViewText(R.id.pomodoro_widget_topic, "\uD83D\uDCCC $topic")
                } else {
                    views.setViewVisibility(R.id.pomodoro_widget_topic, View.GONE)
                }

                views.setProgressBar(R.id.pomodoro_progress_bar, 100, progress.coerceIn(0, 100), false)

                if (sessions > 0) {
                    views.setViewVisibility(R.id.pomodoro_session_chips, View.VISIBLE)
                    views.setTextViewText(R.id.completed_sessions, "$sessions")
                } else {
                    views.setViewVisibility(R.id.pomodoro_session_chips, View.GONE)
                }

                if (isFocusing && distractions > 0) {
                    views.setViewVisibility(R.id.distraction_chip, View.VISIBLE)
                    views.setTextViewText(R.id.distraction_text, "$distractions")
                } else {
                    views.setViewVisibility(R.id.distraction_chip, View.GONE)
                }

                if (isBreak && !nextSubject.isNullOrEmpty()) {
                    views.setViewVisibility(R.id.next_subject_chip, View.VISIBLE)
                    views.setTextViewText(R.id.next_subject_text, "Next: $nextSubject")
                } else {
                    views.setViewVisibility(R.id.next_subject_chip, View.GONE)
                }

                if (dailyGoal > 0) {
                    views.setViewVisibility(R.id.daily_goal_container, View.VISIBLE)
                    views.setTextViewText(R.id.daily_goal_text, "$dailyMinutes / $dailyGoal min")
                    val goalPercent = ((dailyMinutes.toFloat() / dailyGoal) * 100).toInt().coerceIn(0, 100)
                    views.setProgressBar(R.id.daily_goal_progress, 100, goalPercent, false)
                } else {
                    views.setViewVisibility(R.id.daily_goal_container, View.GONE)
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
                android.util.Log.i("PomodoroWidget", "Widget $widgetId updated successfully")

                val interval = if (isFocusing || isBreak) ACTIVE_TICK_INTERVAL_MS else IDLE_TICK_INTERVAL_MS
                scheduleTick(context, interval)

            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "Update failed for widget $widgetId", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)
                    fallbackViews.setTextViewText(R.id.pomodoro_widget_timer, "--:--")
                    fallbackViews.setTextViewText(R.id.pomodoro_widget_status, "Tap to open app")
                    fallbackViews.setTextViewText(R.id.pomodoro_widget_subject, "Pomodoro Timer")
                    fallbackViews.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", Color.parseColor("#0F0F23"))
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (e2: Exception) {
                    android.util.Log.e("PomodoroWidget", "Fallback also failed", e2)
                }
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
                android.util.Log.e("PomodoroWidget", "Schedule tick failed", e)
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
        scheduleTick(context, IDLE_TICK_INTERVAL_MS)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
        scheduleTick(context, IDLE_TICK_INTERVAL_MS)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
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