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
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SMART_COUNTDOWN = "flutter.smart_countdown_enabled"
        private const val WIDGET_DATA_FILE = "widget_data.json"

        const val ACTION_EVENT_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"
        private const val TICK_INTERVAL_MS = 60_000L // 1 minute

        // ═══════════════════════════════════════════════════════════════
        // FIXED: Day rounding — use ceiling for "X days left" to match app
        // ═══════════════════════════════════════════════════════════════
        private fun formatCountdownDays(deadlineMillis: Long, smartCountdown: Boolean): String {
            val now = System.currentTimeMillis()
            val diff = deadlineMillis - now

            if (diff <= 0) return "Now"

            val days = TimeUnit.MILLISECONDS.toDays(diff)
            val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
            val minutes = TimeUnit.MILLISECONDS.toMinutes(diff) % 60

            return when {
                days > 0L -> {
                    // FIXED: Ceiling for days to match app behavior
                    val displayDays = if (hours > 0L || minutes > 0L) days + 1L else days
                    "$displayDays day${if (displayDays == 1L) "" else "s"} left"
                }
                hours > 0L -> "$hours hour${if (hours == 1L) "" else "s"} left"
                else -> "$minutes minute${if (minutes == 1L) "" else "s"} left"
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // NEW: Smart study nudge based on time until event
        // ═══════════════════════════════════════════════════════════════
        private fun getStudyNudge(deadlineMillis: Long, subjectTag: String?, priority: Int): String {
            val now = System.currentTimeMillis()
            val diff = deadlineMillis - now
            val days = TimeUnit.MILLISECONDS.toDays(diff)

            val subject = subjectTag?.takeIf { it.isNotBlank() } ?: "this"

            return when {
                days <= 0L -> "Exam is now! Good luck!"
                days == 1L -> "Last day! Quick review of $subject"
                days <= 3L -> "High intensity: focus $subject weak areas"
                days <= 7L -> "Weekly plan: 2-3 hrs/day on $subject"
                days <= 14L -> "Start $subject revision schedule"
                days <= 30L -> "Build $subject concept notes"
                priority >= 3 -> "$subject: begin early prep"
                else -> "On track with $subject"
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // NEW: Progress ring calculation for daily study goal
        // ═══════════════════════════════════════════════════════════════
        private fun calculateGoalProgress(achieved: Int, target: Int): Int {
            if (target <= 0) return 0
            return ((achieved.toFloat() / target.toFloat()) * 100).toInt().coerceIn(0, 100)
        }

        // ═══════════════════════════════════════════════════════════════
        // NEW: Subject color mapping for widget theming
        // ═══════════════════════════════════════════════════════════════
        private fun getSubjectColor(subjectTag: String?): String {
            return when (subjectTag?.lowercase(Locale.getDefault())) {
                "physics" -> "#E53935"      // Red
                "chemistry" -> "#1E88E5"   // Blue
                "biology" -> "#43A047"     // Green
                "math", "mathematics" -> "#FB8C00" // Orange
                "english" -> "#8E24AA"     // Purple
                "history" -> "#6D4C41"     // Brown
                "combined test", "test" -> "#00897B" // Teal
                else -> "#00897B"           // Default teal
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val smartCountdown = prefs.getBoolean(KEY_SMART_COUNTDOWN, true)

                // ── Read event data from JSON file written by widget_service.dart ──
                var title = "No upcoming events"
                var countdownText = "Open app to add events"
                var progress = 0
                var urgencyLabel = ""
                var urgencyColorKey = ""
                var subjectTag: String? = null
                var priority = 2
                var streakCount = 0
                var dailyGoalAchieved = 0
                var dailyGoalTarget = 120
                var subtasksJson: JSONArray? = null
                var upcomingEventsJson: JSONArray? = null
                var deadlineMillis = 0L
                var isCompleted = false

                try {
                    val file = File(context.filesDir, WIDGET_DATA_FILE)
                    if (file.exists()) {
                        val json = JSONObject(file.readText())
                        title = json.optString("title", title)
                        countdownText = json.optString("countdown", countdownText)
                        progress = json.optInt("progressPercent", 0)
                        urgencyLabel = json.optString("urgencyLabel", "")
                        urgencyColorKey = json.optString("urgencyColor", "")
                        subjectTag = json.optString("subjectTag", null)
                        priority = json.optInt("priority", 2)
                        streakCount = json.optInt("streakCount", 0)
                        dailyGoalAchieved = json.optInt("dailyGoalAchieved", 0)
                        dailyGoalTarget = json.optInt("dailyGoalTarget", 120)
                        deadlineMillis = json.optLong("deadlineMillis", 0L)
                        isCompleted = json.optBoolean("isCompleted", false)

                        if (json.has("subtasks")) {
                            subtasksJson = json.getJSONArray("subtasks")
                        }
                        if (json.has("upcomingEvents")) {
                            upcomingEventsJson = json.getJSONArray("upcomingEvents")
                        }

                        // FIXED: Proper day rounding for countdown
                        if (deadlineMillis > 0L) {
                            countdownText = formatCountdownDays(deadlineMillis, smartCountdown)
                        }

                        // If smart countdown is OFF, show absolute date
                        if (!smartCountdown && deadlineMillis > 0L) {
                            val sdf = SimpleDateFormat("MMM d, yyyy HH:mm", Locale.getDefault())
                            countdownText = sdf.format(Date(deadlineMillis))
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("EventWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                // ── MAIN EVENT INFO ──
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdownText)

                // Progress ring (0-100)
                views.setProgressBar(R.id.widget_progress_ring, 100, progress.coerceIn(0, 100), false)

                // ── URGENCY ROW: colored dot + label ──
                if (urgencyLabel.isNotEmpty() && !isCompleted) {
                    views.setViewVisibility(R.id.widget_urgency_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_urgency_dot, "●")
                    views.setTextColor(R.id.widget_urgency_dot, Color.parseColor("#FFFFFF"))
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, Color.parseColor("#FFFFFF"))

                    val pillDrawableRes = when (urgencyColorKey) {
                        "red" -> R.drawable.widget_pill_red
                        "deepOrange" -> R.drawable.widget_pill_orange
                        "orange" -> R.drawable.widget_pill_orange
                        "green" -> R.drawable.widget_pill_green
                        else -> R.drawable.widget_pill_orange
                    }
                    views.setInt(R.id.widget_urgency_label, "setBackgroundResource", pillDrawableRes)
                } else {
                    views.setViewVisibility(R.id.widget_urgency_row, View.GONE)
                }

                // ── NEW: PRIORITY BADGE ──
                if (priority >= 3 && !isCompleted) {
                    views.setViewVisibility(R.id.widget_priority_badge, View.VISIBLE)
                    val priorityText = when (priority) {
                        3 -> "High"
                        4 -> "Urgent"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_priority_badge, priorityText)
                    val priorityColor = when (priority) {
                        4 -> Color.parseColor("#E53935")
                        3 -> Color.parseColor("#FB8C00")
                        else -> Color.parseColor("#757575")
                    }
                    views.setTextColor(R.id.widget_priority_badge, priorityColor)
                } else {
                    views.setViewVisibility(R.id.widget_priority_badge, View.GONE)
                }

                // ── NEW: SUBJECT TAG CHIP ──
                if (!subjectTag.isNullOrBlank()) {
                    views.setViewVisibility(R.id.widget_subject_chip, View.VISIBLE)
                    views.setTextViewText(R.id.widget_subject_chip, subjectTag)
                    val subjectColor = getSubjectColor(subjectTag)
                    views.setTextColor(R.id.widget_subject_chip, Color.parseColor(subjectColor))
                } else {
                    views.setViewVisibility(R.id.widget_subject_chip, View.GONE)
                }

                // ── NEW: STUDY STREAK INDICATOR ──
                if (streakCount > 0) {
                    views.setViewVisibility(R.id.widget_streak_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_streak_text, "🔥 $streakCount day streak")
                } else {
                    views.setViewVisibility(R.id.widget_streak_row, View.GONE)
                }

                // ── NEW: SMART STUDY NUDGE ──
                if (!isCompleted && deadlineMillis > 0L) {
                    views.setViewVisibility(R.id.widget_nudge_row, View.VISIBLE)
                    val nudge = getStudyNudge(deadlineMillis, subjectTag, priority)
                    views.setTextViewText(R.id.widget_nudge_text, nudge)
                } else {
                    views.setViewVisibility(R.id.widget_nudge_row, View.GONE)
                }

                // ── NEW: DAILY STUDY GOAL MINI-RING ──
                val goalProgress = calculateGoalProgress(dailyGoalAchieved, dailyGoalTarget)
                if (dailyGoalTarget > 0) {
                    views.setViewVisibility(R.id.widget_goal_row, View.VISIBLE)
                    views.setProgressBar(R.id.widget_goal_ring, 100, goalProgress, false)
                    views.setTextViewText(R.id.widget_goal_text,
                        "$dailyGoalAchieved/$dailyGoalTarget min")

                    // Color based on progress
                    val goalColor = when {
                        goalProgress >= 100 -> Color.parseColor("#43A047")
                        goalProgress >= 50 -> Color.parseColor("#FB8C00")
                        else -> Color.parseColor("#E53935")
                    }
                    views.setTextColor(R.id.widget_goal_text, goalColor)
                } else {
                    views.setViewVisibility(R.id.widget_goal_row, View.GONE)
                }

                // ── NEW: SUBTASKS PREVIEW (up to 3) ──
                if (subtasksJson != null && subtasksJson.length() > 0) {
                    views.setViewVisibility(R.id.widget_subtasks_container, View.VISIBLE)

                    val subtaskViews = listOf(
                        R.id.widget_subtask_1,
                        R.id.widget_subtask_2,
                        R.id.widget_subtask_3
                    )
                    val subtaskCheckViews = listOf(
                        R.id.widget_subtask_check_1,
                        R.id.widget_subtask_check_2,
                        R.id.widget_subtask_check_3
                    )

                    // Hide all first
                    for (viewId in subtaskViews) {
                        views.setViewVisibility(viewId, View.GONE)
                    }
                    for (viewId in subtaskCheckViews) {
                        views.setViewVisibility(viewId, View.GONE)
                    }

                    val count = minOf(subtasksJson.length(), 3)
                    for (i in 0 until count) {
                        val st = subtasksJson.getJSONObject(i)
                        val stTitle = st.optString("title", "")
                        val stCompleted = st.optBoolean("completed", false)

                        if (stTitle.isNotBlank()) {
                            views.setViewVisibility(subtaskViews[i], View.VISIBLE)
                            views.setViewVisibility(subtaskCheckViews[i], View.VISIBLE)
                            views.setTextViewText(subtaskViews[i], stTitle)

                            // Strike-through for completed
                            if (stCompleted) {
                                views.setInt(subtaskViews[i], "setPaintFlags",
                                    android.graphics.Paint.STRIKE_THRU_TEXT_FLAG)
                                views.setTextColor(subtaskViews[i], Color.parseColor("#9E9E9E"))
                            } else {
                                views.setInt(subtaskViews[i], "setPaintFlags", 0)
                                views.setTextColor(subtaskViews[i], Color.parseColor("#FFFFFF"))
                            }

                            // Check icon color
                            val checkColor = if (stCompleted) "#43A047" else "#757575"
                            views.setTextColor(subtaskCheckViews[i], Color.parseColor(checkColor))
                        }
                    }

                    // Show "+X more" if there are more subtasks
                    if (subtasksJson.length() > 3) {
                        views.setViewVisibility(R.id.widget_subtasks_more, View.VISIBLE)
                        views.setTextViewText(R.id.widget_subtasks_more,
                            "+${subtasksJson.length() - 3} more")
                    } else {
                        views.setViewVisibility(R.id.widget_subtasks_more, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_subtasks_container, View.GONE)
                }

                // ── NEW: UPCOMING EVENTS MINI-LIST ──
                if (upcomingEventsJson != null && upcomingEventsJson.length() > 0) {
                    views.setViewVisibility(R.id.widget_upcoming_container, View.VISIBLE)

                    val upcomingViews = listOf(
                        R.id.widget_upcoming_1,
                        R.id.widget_upcoming_2
                    )
                    val upcomingDateViews = listOf(
                        R.id.widget_upcoming_date_1,
                        R.id.widget_upcoming_date_2
                    )

                    for (viewId in upcomingViews) {
                        views.setViewVisibility(viewId, View.GONE)
                    }
                    for (viewId in upcomingDateViews) {
                        views.setViewVisibility(viewId, View.GONE)
                    }

                    val count = minOf(upcomingEventsJson.length(), 2)
                    for (i in 0 until count) {
                        val ev = upcomingEventsJson.getJSONObject(i)
                        val evTitle = ev.optString("title", "")
                        val evDays = ev.optInt("daysUntil", 0)
                        val evSubject = ev.optString("subjectTag", "")

                        if (evTitle.isNotBlank()) {
                            views.setViewVisibility(upcomingViews[i], View.VISIBLE)
                            views.setViewVisibility(upcomingDateViews[i], View.VISIBLE)

                            val prefix = if (evSubject.isNotBlank()) "[$evSubject] " else ""
                            views.setTextViewText(upcomingViews[i], "$prefix$evTitle")
                            views.setTextViewText(upcomingDateViews[i],
                                "$evDays day${if (evDays == 1) "" else "s"}")
                        }
                    }
                } else {
                    views.setViewVisibility(R.id.widget_upcoming_container, View.GONE)
                }

                // ── CLICK TO OPEN APP ──
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("EventWidget", "Widget $widgetId updated: smart=$smartCountdown, streak=$streakCount, goal=$dailyGoalAchieved/$dailyGoalTarget")

            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Update failed", e)
            }
        }

        fun scheduleTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                    action = ACTION_EVENT_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 2, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                val triggerAt = SystemClock.elapsedRealtime() + TICK_INTERVAL_MS

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
                android.util.Log.e("EventWidget", "Schedule failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, EventCountdownWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("EventWidget", "Updating ${widgetIds.size} widgets")
            for (widgetId in widgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId)
            }
            scheduleTick(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.i("EventWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
        scheduleTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("EventWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_EVENT_TICK -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> updateAllWidgets(context)
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val widgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (widgetIds != null && widgetIds.isNotEmpty()) {
                    for (widgetId in widgetIds) {
                        updateWidgetDirectly(context, AppWidgetManager.getInstance(context), widgetId)
                    }
                    scheduleTick(context)
                } else {
                    updateAllWidgets(context)
                }
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleTick(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                action = ACTION_EVENT_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 2, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            android.util.Log.e("EventWidget", "Cancel alarm failed", e)
        }
    }
}
