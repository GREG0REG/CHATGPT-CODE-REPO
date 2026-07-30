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

        // IDs for the 3 preset class rows
        private val ROW_IDS = listOf(
            R.id.timetable_class_row_1,
            R.id.timetable_class_row_2,
            R.id.timetable_class_row_3
        )
        private val DOT_IDS = listOf(
            R.id.timetable_class_dot_1,
            R.id.timetable_class_dot_2,
            R.id.timetable_class_dot_3
        )
        private val SUBJECT_IDS = listOf(
            R.id.timetable_class_subject_1,
            R.id.timetable_class_subject_2,
            R.id.timetable_class_subject_3
        )
        private val INFO_IDS = listOf(
            R.id.timetable_class_info_1,
            R.id.timetable_class_info_2,
            R.id.timetable_class_info_3
        )

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
                    // CRITICAL FIX: Use context.filesDir directly — matches Event widget
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
                        android.util.Log.w("TimetableWidget", "Data file not found at: ${file.absolutePath}")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("TimetableWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.timetable_widget_layout)

                // Header: day name + date
                views.setTextViewText(R.id.timetable_widget_day, dayName)
                views.setTextViewText(R.id.timetable_widget_date, dateText)

                if (classesList.isEmpty()) {
                    // Show empty state, hide all rows
                    views.setViewVisibility(R.id.timetable_widget_empty, View.VISIBLE)
                    for (rowId in ROW_IDS) {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                } else {
                    // Hide empty state
                    views.setViewVisibility(R.id.timetable_widget_empty, View.GONE)

                    // Show up to 3 classes
                    for (i in 0 until 3) {
                        if (i < classesList.size) {
                            val cls = classesList[i]
                            val colorHex = cls["colorHex"] ?: "#2196F3"
                            val subject = cls["subject"] ?: "Unknown"
                            val timeSlot = cls["timeSlot"] ?: ""
                            val room = cls["room"] ?: "TBD"
                            val countdownText = cls["countdownText"] ?: ""

                            val color = try {
                                Color.parseColor(colorHex)
                            } catch (e: Exception) {
                                Color.parseColor("#2196F3")
                            }

                            // Format: "9:00 - 10:00  •  Math  •  Hall A  •  25 min"
                            val infoText = "$timeSlot  •  $subject  •  $room  •  $countdownText"

                            views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                            // FIXED: Use setTextColor on TextView "●" instead of setBackgroundColor on View with drawable
                            views.setTextViewText(DOT_IDS[i], "●")
                            views.setTextColor(DOT_IDS[i], color)
                            views.setTextViewText(SUBJECT_IDS[i], subject)
                            views.setTextViewText(INFO_IDS[i], infoText)
                            views.setTextColor(SUBJECT_IDS[i], color)
                        } else {
                            views.setViewVisibility(ROW_IDS[i], View.GONE)
                        }
                    }
                }

                // Tap opens app to /timetable
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
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
