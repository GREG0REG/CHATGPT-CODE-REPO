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
import org.json.JSONObject
import java.io.File

class TimetableWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TIMETABLE_DATA_FILE = "timetable_widget_data.json"

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
                                    "room" to cls.optString("room", "TBD"),
                                    "countdownText" to cls.optString("countdownText", ""),
                                    "colorHex" to cls.optString("colorHex", "#2196F3"),
                                    "isToday" to cls.optBoolean("isToday", true).toString()
                                ))
                            }
                        }
                    } else {
                        android.util.Log.w("TimetableWidget", "Data file not found: ${file.absolutePath}")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("TimetableWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.timetable_widget_layout)

                views.setTextViewText(R.id.timetable_widget_day, dayName)
                views.setTextViewText(R.id.timetable_widget_date, dateText)

                if (classesList.isEmpty()) {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.timetable_widget_empty, "No upcoming classes")
                    views.setTextColor(R.id.timetable_widget_empty, Color.parseColor("#88FFFFFF"))
                    
                    // Hide class rows
                    views.setViewVisibility(R.id.timetable_class_1, View.GONE)
                    views.setViewVisibility(R.id.timetable_class_2, View.GONE)
                    views.setViewVisibility(R.id.timetable_class_3, View.GONE)
                } else {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.GONE)
                    
                    // Show up to 3 classes using preset rows
                    val rowIds = listOf(
                        R.id.timetable_class_1,
                        R.id.timetable_class_2,
                        R.id.timetable_class_3
                    )
                    val subjectIds = listOf(
                        R.id.timetable_class_1_subject,
                        R.id.timetable_class_2_subject,
                        R.id.timetable_class_3_subject
                    )
                    val timeIds = listOf(
                        R.id.timetable_class_1_time,
                        R.id.timetable_class_2_time,
                        R.id.timetable_class_3_time
                    )
                    val roomIds = listOf(
                        R.id.timetable_class_1_room,
                        R.id.timetable_class_2_room,
                        R.id.timetable_class_3_room
                    )
                    val dotIds = listOf(
                        R.id.timetable_class_1_dot,
                        R.id.timetable_class_2_dot,
                        R.id.timetable_class_3_dot
                    )

                    for (i in 0 until 3) {
                        if (i < classesList.size) {
                            val cls = classesList[i]
                            val colorHex = cls["colorHex"] ?: "#2196F3"
                            val color = try {
                                Color.parseColor(colorHex)
                            } catch (e: Exception) {
                                Color.parseColor("#2196F3")
                            }

                            views.setViewVisibility(rowIds[i], View.VISIBLE)
                            views.setTextViewText(subjectIds[i], cls["subject"])
                            views.setTextViewText(timeIds[i], "${cls["timeSlot"]}  •  ${cls["countdownText"]}")
                            views.setTextViewText(roomIds[i], "📍 ${cls["room"]}")
                            views.setTextColor(dotIds[i], color)
                        } else {
                            views.setViewVisibility(rowIds[i], View.GONE)
                        }
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
}
