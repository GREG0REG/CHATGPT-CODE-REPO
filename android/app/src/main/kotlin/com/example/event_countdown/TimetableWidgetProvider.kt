package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TimetableWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TIMETABLE_DATA_FILE = "timetable_widget_data.json"
        private const val ACTION_REFRESH = "com.example.event_countdown.TIMETABLE_WIDGET_REFRESH"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                var dayName = "Today"
                var dateText = ""
                val classesList = mutableListOf<Map<String, String>>()

                try {
                    val file = File(context.filesDir, TIMETABLE_DATA_FILE)
                    if (file.exists()) {
                        val json = JSONObject(file.readText())
                        dayName = json.optString("dayName", dayName)
                        dateText = json.optString("dateText", dateText)
                        val classesArray = json.optJSONArray("classes")
                        if (classesArray != null) {
                            for (i in 0 until classesArray.length()) {
                                val cls = classesArray.getJSONObject(i)
                                classesList.add(mapOf(
                                    "subject" to cls.optString("subject", "Unknown"),
                                    "timeSlot" to cls.optString("timeSlot", ""),
                                    "colorHex" to cls.optString("colorHex", "#2196F3")
                                ))
                            }
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("TimetableWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.timetable_widget_layout)

                views.setTextViewText(R.id.timetable_widget_day, dayName)
                views.setTextViewText(R.id.timetable_widget_date, dateText)

                // Build class items dynamically
                if (classesList.isEmpty()) {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.GONE)
                    
                    // Add up to 4 classes (widget space limited)
                    for ((index, cls) in classesList.take(4).withIndex()) {
                        val subject = cls["subject"] ?: "Unknown"
                        val timeSlot = cls["timeSlot"] ?: ""
                        val colorHex = cls["colorHex"] ?: "#2196F3"
                        
                        val color = try {
                            Color.parseColor(colorHex)
                        } catch (e: Exception) {
                            Color.parseColor("#2196F3")
                        }

                        // We can't dynamically add views, so we use preset IDs
                        // For simplicity, we show first class prominently
                        if (index == 0) {
                            views.setTextViewText(R.id.timetable_widget_empty, "$timeSlot — $subject")
                            views.setTextColor(R.id.timetable_widget_empty, color)
                            views.setViewVisibility(R.id.timetable_widget_empty, View.VISIBLE)
                        }
                    }
                    
                    // If multiple classes, show count
                    if (classesList.size > 1) {
                        val firstText = views.getLayoutId() // workaround
                        views.setTextViewText(
                            R.id.timetable_widget_empty,
                            "${classesList.size} classes today"
                        )
                        views.setTextColor(R.id.timetable_widget_empty, Color.parseColor("#FFFFFF"))
                    }
                }

                // Launch intent
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("route", "/timetable")
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId + 2000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.timetable_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("TimetableWidget", "Widget $widgetId updated: ${classesList.size} classes")

            } catch (e: Exception) {
                android.util.Log.e("TimetableWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TimetableWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("TimetableWidget", "Updating ${widgetIds.size} widgets")
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
        android.util.Log.i("TimetableWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("TimetableWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            ACTION_REFRESH -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val widgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (widgetIds != null && widgetIds.isNotEmpty()) {
                    val manager = AppWidgetManager.getInstance(context)
                    for (widgetId in widgetIds) {
                        updateWidgetDirectly(context, manager, widgetId)
                    }
                } else {
                    updateAllWidgets(context)
                }
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.i("TimetableWidget", "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        android.util.Log.i("TimetableWidget", "Widget disabled")
    }
}
