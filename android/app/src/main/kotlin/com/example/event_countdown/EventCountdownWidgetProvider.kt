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
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"

        fun ensureTestData(context: Context) {
            try {
                val file = File(context.filesDir, "widget_data.json")
                if (!file.exists()) {
                    // Create test data so widget shows something
                    val testData = JSONObject().apply {
                        put("title", "Open app to add events")
                        put("countdown", "Event Countdown")
                        put("deadlineMillis", System.currentTimeMillis() + 86400000)
                        put("startMillis", System.currentTimeMillis())
                        put("progressPercent", 25)
                        put("urgencyColor", "orange")
                        put("smartFormat", true)
                        put("bgColor", "#00BFA5")
                        put("textColor", "#FFFFFF")
                    }
                    file.writeText(testData.toString())
                    android.util.Log.i("EventWidget", "Created test data at ${file.absolutePath}")
                }
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Failed to create test data", e)
            }
        }

        fun readWidgetData(context: Context): Map<String, Any?> {
            return try {
                ensureTestData(context)

                val file = File(context.filesDir, "widget_data.json")
                if (!file.exists()) {
                    android.util.Log.e("EventWidget", "widget_data.json NOT FOUND at ${file.absolutePath}")
                    return emptyMap()
                }

                val jsonString = file.readText()
                if (jsonString.isBlank()) {
                    android.util.Log.e("EventWidget", "widget_data.json is EMPTY")
                    return emptyMap()
                }

                android.util.Log.d("EventWidget", "Reading from: ${file.absolutePath}")
                android.util.Log.d("EventWidget", "Content: $jsonString")

                val json = JSONObject(jsonString)
                val result = mutableMapOf<String, Any?>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    result[key] = json.opt(key)
                }
                result
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Failed to read", e)
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
                    } else storedProgress

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

                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

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
                android.util.Log.i("EventWidget", "Widget $widgetId updated: $title | $countdownText")

                if (deadlineMillis != null && deadlineMillis > System.currentTimeMillis()) {
                    scheduleTick(context)
                }

            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Update failed", e)
            }
        }

        fun scheduleTick(context: Context) {
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
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 60_000,
                    pendingIntent
                )
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
                val data = readWidgetData(context)
                val deadlineMillis = (data["deadlineMillis"] as? Number)?.toLong()?.takeIf { it > 0 }
                val remaining = deadlineMillis?.let { it - System.currentTimeMillis() } ?: 0
                if (remaining > 0) scheduleTick(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                val data = readWidgetData(context)
                val deadlineMillis = (data["deadlineMillis"] as? Number)?.toLong()?.takeIf { it > 0 }
                if (deadlineMillis != null && deadlineMillis > System.currentTimeMillis()) {
                    updateAllWidgets(context)
                    scheduleTick(context)
                }
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
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
        } catch (e: Exception) {}
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
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
        } catch (e: Exception) {}
    }
}
