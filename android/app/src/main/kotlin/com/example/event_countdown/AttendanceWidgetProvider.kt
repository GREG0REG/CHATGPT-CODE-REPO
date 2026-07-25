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

class AttendanceWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ATTENDANCE_DATA_FILE = "attendance_widget_data.json"
        private const val ACTION_REFRESH = "com.example.event_countdown.ATTENDANCE_WIDGET_REFRESH"

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

                try {
                    val file = File(context.filesDir, ATTENDANCE_DATA_FILE)
                    if (file.exists()) {
                        val json = JSONObject(file.readText())
                        subjectName = json.optString("subjectName", subjectName)
                        attended = json.optInt("attended", 0)
                        total = json.optInt("total", 0)
                        percentage = json.optInt("percentage", 0)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("AttendanceWidget", "JSON read failed", e)
                }

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                views.setTextViewText(R.id.attendance_widget_subject, subjectName)
                views.setTextViewText(R.id.attendance_widget_ratio, "$attended/$total")
                views.setTextViewText(R.id.attendance_widget_percent, "$percentage%")
                views.setProgressBar(R.id.attendance_widget_progress, 100, percentage.coerceIn(0, 100), false)

                // Color based on percentage
                val statusText = when {
                    percentage >= 75 -> "Good standing"
                    percentage >= 60 -> "Warning"
                    else -> "At risk"
                }
                val statusColor = when {
                    percentage >= 75 -> "#FF4CAF50" // Green
                    percentage >= 60 -> "#FFFF9800" // Orange
                    else -> "#FFF44336" // Red
                }

                views.setTextViewText(R.id.attendance_widget_status, statusText)
                views.setTextColor(R.id.attendance_widget_status, Color.parseColor(statusColor))

                // Progress ring color
                val progressDrawableRes = when {
                    percentage >= 75 -> R.drawable.widget_circular_progress_green
                    percentage >= 60 -> R.drawable.widget_circular_progress_orange
                    else -> R.drawable.widget_circular_progress_red
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
        android.util.Log.i("AttendanceWidget", "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        android.util.Log.i("AttendanceWidget", "Widget disabled")
    }
}
