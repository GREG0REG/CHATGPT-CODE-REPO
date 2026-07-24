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
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"
        private const val TICK_INTERVAL_MS = 60_000L // 60 seconds

        fun readWidgetData(context: Context): Map<String, Any?> {
            return try {
                val file = File(context.filesDir, "widget_data.json")
                if (!file.exists()) {
                    android.util.Log.w("EventWidget", "File not found: ${file.absolutePath}")
                    return emptyMap()
                }

                val jsonString = file.readText()
                if (jsonString.isBlank()) {
                    android.util.Log.w("EventWidget", "File is empty")
                    return emptyMap()
                }

                android.util.Log.d("EventWidget", "File content: $jsonString")

                val json = JSONObject(jsonString)
                val result = mutableMapOf<String, Any?>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    result[key] = json.opt(key)
                }
                result
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Read error", e)
                emptyMap()
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val data = readWidgetData(context)
                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                // If no data file, show placeholder
                if (data.isEmpty()) {
                    views.setTextViewText(R.id.widget_title, "No upcoming events")
                    views.setTextViewText(R.id.widget_countdown, "Open app to add events")
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.GONE)
                    views.setProgressBar(R.id.widget_progress_ring, 100, 0, false)
                    views.setInt(R.id.widget_root, "setBackgroundColor", Color.parseColor("#00BFA5"))
                    views.setTextColor(R.id.widget_title, Color.WHITE)
                    views.setTextColor(R.id.widget_countdown, Color.WHITE)

                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        val pendingIntent = PendingIntent.getActivity(
                            context, 0, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                    }

                    appWidgetManager.updateAppWidget(widgetId, views)
                    android.util.Log.i("EventWidget", "Widget $widgetId: No data file")
                    
                    // ALWAYS schedule next tick to check for updates
                    scheduleTick(context, TICK_INTERVAL_MS)
                    return
                }

                val title = data["title"] as? String ?: "No upcoming events"
                val storedCountdown = data["countdown"] as? String ?: ""
                val bgColorStr = data["bgColor"] as? String
                val textColorStr = data["textColor"] as? String
                val storedProgress = (data["progressPercent"] as? Number)?.toInt() ?: 0
                val storedUrgency = data["urgencyColor"] as? String

                val deadlineMillis = (data["deadlineMillis"] as? Number)?.toLong()?.takeIf { it > 0 }
                val startMillis = (data["startMillis"] as? Number)?.toLong()?.takeIf { it > 0 }
                val smartFormat = data["smartFormat"] as? Boolean ?: true

                val countdownText: String
                val progressPercent: Int
                val urgencyColorName: String?

                if (deadlineMillis != null) {
                    val now = System.currentTimeMillis()
                    val diff = deadlineMillis - now
                    if (diff <= 0) {
                        countdownText = "Due now"
                    } else {
                        val days = TimeUnit.MILLISECONDS.toDays(diff)
                        val hours = TimeUnit.MILLISECONDS.toHours(diff) % 24
                        val minutes = TimeUnit.MILLISECONDS.toMinutes(diff) % 60
                        countdownText = if (smartFormat) {
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
                    val total = deadlineMillis - (startMillis ?: deadlineMillis)
                    progressPercent = if (total > 0) {
                        val elapsed = System.currentTimeMillis() - (startMillis ?: deadlineMillis)
                        ((elapsed.toFloat() / total) * 100).toInt().coerceIn(0, 100)
                    } else 0

                    val days = TimeUnit.MILLISECONDS.toDays(deadlineMillis - System.currentTimeMillis())
                    urgencyColorName = when {
                        days < 1 -> "red"
                        days < 3 -> "deepOrange"
                        days < 7 -> "orange"
                        days < 30 -> "green"
                        else -> null
                    }
                } else {
                    countdownText = storedCountdown
                    progressPercent = storedProgress
                    urgencyColorName = storedUrgency
                }

                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdownText)
                views.setProgressBar(R.id.widget_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                val themeColor = try {
                    if (bgColorStr.isNullOrEmpty()) Color.parseColor("#00BFA5") else Color.parseColor(bgColorStr)
                } catch (e: Exception) { Color.parseColor("#00BFA5") }

                val textColor = try {
                    if (textColorStr.isNullOrEmpty()) Color.WHITE else Color.parseColor(textColorStr)
                } catch (e: Exception) { Color.WHITE }

                views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)

                val showUrgency = urgencyColorName != null && urgencyColorName != "green" && urgencyColorName != "grey"
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

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, 0, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("EventWidget", "Widget $widgetId: $title | $countdownText")

                // ALWAYS schedule next tick, regardless of state
                scheduleTick(context, TICK_INTERVAL_MS)

            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Update failed", e)
                // Even on failure, schedule next tick to retry
                scheduleTick(context, TICK_INTERVAL_MS)
            }
        }

        fun scheduleTick(context: Context, intervalMillis: Long) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
                
                val triggerAt = SystemClock.elapsedRealtime() + intervalMillis
                
                // Try exact alarm first for precision
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
                    // Fallback for Android 12+ without exact alarm permission
                    android.util.Log.w("EventWidget", "Exact alarm not permitted, using fallback")
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
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        android.util.Log.i("EventWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("EventWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_WIDGET_TICK -> {
                updateAllWidgets(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                updateAllWidgets(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                updateAllWidgets(context)
            }
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> {
                updateAllWidgets(context)
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
            val intent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_TICK
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            android.util.Log.e("EventWidget", "Cancel alarm failed", e)
        }
    }
}
