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
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SMART_COUNTDOWN = "flutter.smart_countdown_enabled"
        private const val WIDGET_DATA_FILE = "widget_data.json"

        const val ACTION_EVENT_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"
        private const val TICK_INTERVAL_MS = 60_000L // 1 minute

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val smartCountdown = prefs.getBoolean(KEY_SMART_COUNTDOWN, true)

                // Read event data from JSON file written by widget_service.dart
                var title = "No upcoming events"
                var countdownText = "Open app to add events"
                var progress = 0
                var urgencyLabel = ""
                var urgencyColorKey = ""

                try {
                    // This path MUST match Dart's getApplicationSupportDirectory()
                    val file = File(context.filesDir, WIDGET_DATA_FILE)
                    if (file.exists()) {
                        val json = JSONObject(file.readText())
                        title = json.optString("title", title)
                        countdownText = json.optString("countdown", countdownText)
                        progress = json.optInt("progressPercent", 0)
                        urgencyLabel = json.optString("urgencyLabel", "")
                        urgencyColorKey = json.optString("urgencyColor", "")

                        // CRITICAL FIX: If smart countdown is OFF, show absolute date
                        val deadlineMillis = json.optLong("deadlineMillis", 0L)
                        if (!smartCountdown && deadlineMillis > 0) {
                            val sdf = SimpleDateFormat("MMM d, yyyy HH:mm", Locale.getDefault())
                            countdownText = sdf.format(Date(deadlineMillis))
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("EventWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdownText)
                views.setProgressBar(R.id.widget_progress_ring, 100, progress.coerceIn(0, 100), false)

                // Urgency row: white text on colored pill background
                if (urgencyLabel.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_urgency_row, View.VISIBLE)
                    views.setTextViewText(R.id.widget_urgency_dot, "●")
                    views.setTextColor(R.id.widget_urgency_dot, Color.parseColor("#FFFFFF"))
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, Color.parseColor("#FFFFFF"))

                    // Map urgency color key to pill background drawable
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

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("EventWidget", "Widget $widgetId updated: smart=$smartCountdown")

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
