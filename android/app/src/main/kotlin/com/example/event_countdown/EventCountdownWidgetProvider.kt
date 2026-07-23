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

class EventCountdownWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        private const val KEY_PROGRESS = "widget_progress_percent"
        private const val KEY_URGENCY_COLOR = "widget_urgency_color"
        
        // NEW: Keys for LIVE countdown calculation
        private const val KEY_EVENT_DEADLINE = "widget_event_deadline_millis"
        private const val KEY_EVENT_START = "widget_event_start_millis"
        private const val KEY_SMART_FORMAT = "widget_smart_format_enabled"

        // Alarm actions
        const val ACTION_WIDGET_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"
        const val ACTION_WIDGET_UPDATE = "com.example.event_countdown.EVENT_WIDGET_UPDATE"

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        /**
         * Build a human-readable countdown string from remaining milliseconds.
         * Matches the Flutter smart format logic.
         */
        fun buildLiveCountdown(deadlineMillis: Long, smartFormat: Boolean): String {
            val now = System.currentTimeMillis()
            val diff = deadlineMillis - now
            
            if (diff <= 0) return "Due now"
            
            val days = TimeUnit.MILLISECONDS.toDays(diff)
            val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
            val minutes = TimeUnit.MILLISECONDS.toMinutes(diff) % 60
            
            return if (smartFormat) {
                when {
                    days > 30 -> "$days days left"
                    days > 0 -> "$days days ${hours}h left"
                    hours > 0 -> "$hours hours ${minutes}m left"
                    else -> "$minutes min left"
                }
            } else {
                when {
                    days > 0 -> "$days days left"
                    hours > 0 -> "$hours hours left"
                    else -> "$minutes min left"
                }
            }
        }

        /**
         * Calculate progress percentage from stored start/deadline times.
         */
        fun calculateLiveProgress(startMillis: Long?, deadlineMillis: Long?): Int {
            if (startMillis == null || deadlineMillis == null) return 65
            val total = deadlineMillis - startMillis
            if (total <= 0) return 65
            val now = System.currentTimeMillis()
            val elapsed = now - startMillis
            return ((elapsed.toFloat() / total) * 100).toInt().coerceIn(0, 100)
        }

        /**
         * Determine urgency color based on remaining time.
         */
        fun getLiveUrgencyColorName(deadlineMillis: Long): String? {
            val now = System.currentTimeMillis()
            val diff = deadlineMillis - now
            val days = TimeUnit.MILLISECONDS.toDays(diff)
            
            return when {
                days < 1 -> "red"
                days < 3 -> "deepOrange"
                days < 7 -> "orange"
                days < 30 -> "green"
                else -> null // grey / no indicator
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            prefs: android.content.SharedPreferences? = null
        ) {
            try {
                val sharedPrefs = prefs ?: context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                val title = sharedPrefs.getString(KEY_TITLE, "No upcoming events") ?: "No upcoming events"
                val storedCountdown = sharedPrefs.getString(KEY_COUNTDOWN, "") ?: ""
                val bgColorStr = sharedPrefs.getString(KEY_BG_COLOR, null)
                val textColorStr = sharedPrefs.getString(KEY_TEXT_COLOR, null)
                val storedProgress = sharedPrefs.getInt(KEY_PROGRESS, 65)
                val storedUrgency = sharedPrefs.getString(KEY_URGENCY_COLOR, null)
                
                // LIVE data
                val deadlineMillis = sharedPrefs.getLong(KEY_EVENT_DEADLINE, 0L).takeIf { it > 0 }
                val startMillis = sharedPrefs.getLong(KEY_EVENT_START, 0L).takeIf { it > 0 }
                val smartFormat = sharedPrefs.getBoolean(KEY_SMART_FORMAT, true)

                // Use LIVE calculated values if we have a deadline, otherwise fall back to stored
                val countdownText: String
                val progressPercent: Int
                val urgencyColorName: String?
                
                if (deadlineMillis != null) {
                    countdownText = buildLiveCountdown(deadlineMillis, smartFormat)
                    progressPercent = calculateLiveProgress(startMillis, deadlineMillis)
                    urgencyColorName = getLiveUrgencyColorName(deadlineMillis)
                } else {
                    countdownText = storedCountdown
                    progressPercent = storedProgress
                    urgencyColorName = storedUrgency
                }

                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                // Set text content
                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdownText)

                // Update progress bar with LIVE value
                views.setProgressBar(R.id.widget_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                // Parse theme colors
                val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#00BFA5"))
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)

                // Set background color on the root
                views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)

                // Text colors
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)

                // Urgency indicator - show for orange, deepOrange, red
                val showUrgency = urgencyColorName != null &&
                    urgencyColorName != "green" &&
                    urgencyColorName != "grey"

                if (showUrgency) {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.VISIBLE)
                    val urgencyColor = when (urgencyColorName) {
                        "red" -> Color.parseColor("#F44336")
                        "deepOrange" -> Color.parseColor("#FF5722")
                        "orange" -> Color.parseColor("#FF9800")
                        else -> Color.parseColor("#FF9800")
                    }
                    views.setTextColor(R.id.widget_urgency_dot, urgencyColor)
                    val urgencyLabel = when (urgencyColorName) {
                        "red" -> "URGENT"
                        "deepOrange" -> "Soon"
                        "orange" -> "Upcoming"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, urgencyColor)
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

                // Schedule next tick if we have an active event with a future deadline
                if (deadlineMillis != null && deadlineMillis > System.currentTimeMillis()) {
                    scheduleWidgetTick(context)
                }

            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Update failed", e)
            }
        }

        /**
         * Schedule a precise alarm to update the widget every minute.
         * Uses AlarmManager for reliability even in Doze mode.
         */
        fun scheduleWidgetTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
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

                // Schedule next update in 60 seconds using exact alarm
                val triggerTime = SystemClock.elapsedRealtime() + 60_000
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
                android.util.Log.d("EventWidget", "Scheduled next tick in 60s")
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Failed to schedule tick", e)
            }
        }

        /**
         * Cancel all scheduled widget ticks
         */
        fun cancelWidgetTicks(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                android.util.Log.d("EventWidget", "Cancelled widget ticks")
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Failed to cancel ticks", e)
            }
        }

        /**
         * Update all active event widgets
         */
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, EventCountdownWidgetProvider::class.java)
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
            android.util.Log.e("EventWidget", "onUpdate failed", e)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_WIDGET_TICK -> {
                // Alarm fired - update widget with LIVE time
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val deadlineMillis = prefs.getLong(KEY_EVENT_DEADLINE, 0L).takeIf { it > 0 }
                val remaining = deadlineMillis?.let { it - System.currentTimeMillis() } ?: 0

                // Update all widgets
                updateAllWidgets(context)

                // Schedule next tick if event is still in the future
                if (remaining > 0) {
                    scheduleWidgetTick(context)
                } else {
                    cancelWidgetTicks(context)
                }
            }
            ACTION_WIDGET_UPDATE -> {
                // Explicit update request (from app)
                updateAllWidgets(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                // Device rebooted - restore widget if event was active
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val deadlineMillis = prefs.getLong(KEY_EVENT_DEADLINE, 0L).takeIf { it > 0 }

                if (deadlineMillis != null && deadlineMillis > System.currentTimeMillis()) {
                    updateAllWidgets(context)
                    scheduleWidgetTick(context)
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // Cancel alarms when widget is removed
        cancelWidgetTicks(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Cancel all alarms when last widget is removed
        cancelWidgetTicks(context)
    }
}
