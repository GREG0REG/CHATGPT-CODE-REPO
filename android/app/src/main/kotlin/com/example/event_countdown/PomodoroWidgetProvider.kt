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
import java.util.concurrent.TimeUnit

class PomodoroWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_POMODORO_TICK = "com.example.event_countdown.POMODORO_WIDGET_TICK"
        const val ACTION_POMODORO_UPDATE = "com.example.event_countdown.POMODORO_WIDGET_UPDATE"

        // SharedPreferences keys - MUST match Flutter PomodoroService exactly
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_PHASE = "flutter.pomodoro_phase"
        const val KEY_END_TIME = "flutter.pomodoro_end_time_millis"
        const val KEY_TOTAL_DURATION = "flutter.pomodoro_total_duration_seconds"
        const val KEY_SUBJECT = "flutter.pomodoro_subject"
        const val KEY_STATUS = "flutter.pomodoro_status"
        const val KEY_SESSIONS = "flutter.pomodoro_completed_sessions"
        const val KEY_REMAINING = "flutter.pomodoro_remaining_seconds"
        const val KEY_PROGRESS = "flutter.pomodoro_progress_percent"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = prefs.getLong(KEY_END_TIME, 0)
                val totalDuration = prefs.getInt(KEY_TOTAL_DURATION, 0)
                val subject = prefs.getString(KEY_SUBJECT, "Ready to Focus") ?: "Ready to Focus"
                val status = prefs.getString(KEY_STATUS, "Ready") ?: "Ready"
                val sessions = prefs.getInt(KEY_SESSIONS, 0)
                val savedRemaining = prefs.getInt(KEY_REMAINING, 0)
                val savedProgress = prefs.getInt(KEY_PROGRESS, 0)

                android.util.Log.d("PomodoroWidget", "📝 phase=$phase, endTime=$endTime, subject=$subject, status=$status")

                val now = System.currentTimeMillis()
                val remainingSeconds: Int
                val progressPercent: Int

                if (phase == "focusing" || phase == "shortBreak" || phase == "longBreak") {
                    if (endTime > 0) {
                        val diff = endTime - now
                        remainingSeconds = if (diff > 0) (diff / 1000).toInt() else 0
                        
                        // Calculate progress from remaining time
                        progressPercent = if (totalDuration > 0) {
                            ((totalDuration - remainingSeconds).toFloat() / totalDuration * 100).toInt().coerceIn(0, 100)
                        } else {
                            savedProgress
                        }
                    } else {
                        remainingSeconds = savedRemaining
                        progressPercent = savedProgress
                    }
                } else {
                    remainingSeconds = savedRemaining
                    progressPercent = savedProgress
                }

                val minutes = remainingSeconds / 60
                val seconds = remainingSeconds % 60
                val timeText = String.format("%02d:%02d", minutes, seconds)

                val views = RemoteViews(context.packageName, R.layout.pomodoro_widget_layout)

                // Set text
                views.setTextViewText(R.id.pomodoro_time, timeText)
                views.setTextViewText(R.id.pomodoro_status, status)
                views.setTextViewText(R.id.pomodoro_subject, subject)
                views.setTextViewText(R.id.pomodoro_sessions, "🔥 $sessions")

                // Colors based on phase
                val (bgColor, accentColor) = when (phase) {
                    "focusing" -> Pair(Color.parseColor("#FF6B6B"), Color.parseColor("#FF8E8E"))
                    "shortBreak" -> Pair(Color.parseColor("#4ECDC4"), Color.parseColor("#6EDDD6"))
                    "longBreak" -> Pair(Color.parseColor("#45B7D1"), Color.parseColor("#6BC5DB"))
                    "paused" -> Pair(Color.parseColor("#FFA726"), Color.parseColor("#FFB74D"))
                    else -> Pair(Color.parseColor("#667EEA"), Color.parseColor("#764BA2"))
                }

                views.setInt(R.id.pomodoro_widget_root, "setBackgroundColor", bgColor)
                views.setInt(R.id.pomodoro_progress_ring, "setProgressBackgroundColor", accentColor)

                // Progress ring
                views.setProgressBar(R.id.pomodoro_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Launch intent
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        1,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.pomodoro_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.d("PomodoroWidget", "✅ Widget $widgetId updated: time=$timeText, progress=$progressPercent")

                // Schedule tick if timer is running
                if ((phase == "focusing" || phase == "shortBreak" || phase == "longBreak") && remainingSeconds > 0) {
                    schedulePomodoroTick(context)
                }

            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "❌ Update failed", e)
            }
        }

        fun schedulePomodoroTick(context: Context) {
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
                val triggerTime = SystemClock.elapsedRealtime() + 1_000 // Update every second for smooth countdown
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                android.util.Log.d("PomodoroWidget", "⏰ Tick scheduled in 1s")
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "❌ Failed to schedule tick", e)
            }
        }

        fun cancelPomodoroTicks(context: Context) {
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
                android.util.Log.d("PomodoroWidget", "⏰ Ticks cancelled")
            } catch (e: Exception) {
                android.util.Log.e("PomodoroWidget", "❌ Failed to cancel ticks", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, PomodoroWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.d("PomodoroWidget", "🔄 Updating ${widgetIds.size} pomodoro widgets")
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
        try {
            android.util.Log.d("PomodoroWidget", "🔄 onUpdate called for ${appWidgetIds.size} widgets")
            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId)
            }
        } catch (e: Exception) {
            android.util.Log.e("PomodoroWidget", "❌ onUpdate failed", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.d("PomodoroWidget", "📡 onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_POMODORO_TICK -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                val endTime = prefs.getLong(KEY_END_TIME, 0)
                val remaining = if (endTime > 0) endTime - System.currentTimeMillis() else 0
                
                updateAllWidgets(context)
                
                if ((phase == "focusing" || phase == "shortBreak" || phase == "longBreak") && remaining > 0) {
                    schedulePomodoroTick(context)
                } else {
                    cancelPomodoroTicks(context)
                }
            }
            ACTION_POMODORO_UPDATE -> {
                updateAllWidgets(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val phase = prefs.getString(KEY_PHASE, "idle") ?: "idle"
                if (phase == "focusing" || phase == "shortBreak" || phase == "longBreak") {
                    updateAllWidgets(context)
                    schedulePomodoroTick(context)
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        cancelPomodoroTicks(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelPomodoroTicks(context)
    }
}
