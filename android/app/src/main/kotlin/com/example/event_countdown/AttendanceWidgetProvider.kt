package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class AttendanceWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ATTENDANCE_DATA_FILE = "attendance_widget_data.json"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                var subjectName = "No Subject"
                var attended = 0
                var total = 0
                var percentage = 0
                var statusColorStr = "grey"
                var canMissText = "No data"

                try {
                    val file = File(context.filesDir, ATTENDANCE_DATA_FILE)
                    if (file.exists()) {
                        val json = JSONObject(file.readText())
                        subjectName = json.optString("subjectName", subjectName)
                        attended = json.optInt("attended", 0)
                        total = json.optInt("total", 0)
                        percentage = json.optInt("percentage", 0)
                        statusColorStr = json.optString("statusColor", "grey")
                        canMissText = json.optString("canMissText", "No data")
                    } else {
                        android.util.Log.w("AttendanceWidget", "Data file not found: ${file.absolutePath}")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("AttendanceWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                views.setTextViewText(R.id.attendance_widget_subject, subjectName)
                views.setTextViewText(R.id.attendance_widget_ratio, "$attended/$total")
                views.setTextViewText(R.id.attendance_widget_percent, "$percentage%")
                views.setProgressBar(R.id.attendance_widget_progress, 100, percentage.coerceIn(0, 100), false)

                // Use status color from JSON (red/orange/yellow/green/grey)
                val colorHex = when (statusColorStr) {
                    "red" -> "#FFF44336"
                    "orange" -> "#FFFF9800"
                    "yellow" -> "#FFFFEB3B"
                    "green" -> "#FF4CAF50"
                    else -> "#FF888888"
                }

                views.setTextViewText(R.id.attendance_widget_status, canMissText)
                views.setTextColor(R.id.attendance_widget_status, Color.parseColor(colorHex))

                // Progress ring color
                val progressDrawableRes = when (statusColorStr) {
                    "red" -> R.drawable.widget_circular_progress_red
                    "orange" -> R.drawable.widget_circular_progress_orange
                    "yellow" -> R.drawable.widget_circular_progress_orange
                    "green" -> R.drawable.widget_circular_progress_green
                    else -> R.drawable.widget_circular_progress_green
                }
                views.setInt(R.id.attendance_widget_progress, "setProgressDrawable", progressDrawableRes)

                // Launch intent
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("route", "/attendance")
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId + 1000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.attendance_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: $subjectName $percentage%")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AttendanceWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("AttendanceWidget", "Updating ${widgetIds.size} widgets")
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
        android.util.Log.i("AttendanceWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("AttendanceWidget", "onReceive: ${intent.action}")
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
