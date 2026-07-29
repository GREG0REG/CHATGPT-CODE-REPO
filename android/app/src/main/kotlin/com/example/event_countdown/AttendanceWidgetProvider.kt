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

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            var subjectName = "No Subjects"
            var attended = 0
            var total = 0
            var percentage = 0
            var statusColorStr = "grey"
            var canMissText = "Add subjects to track attendance"
            var streakDays = 0

            try {
                // FIXED: Try multiple possible paths where Flutter might write the file
                val possiblePaths = listOf(
                    File(context.filesDir, ATTENDANCE_DATA_FILE),
                    File(context.filesDir.parentFile, "app_flutter/$ATTENDANCE_DATA_FILE"),
                    File(context.getDir("flutter", Context.MODE_PRIVATE).parentFile, "app_flutter/$ATTENDANCE_DATA_FILE"),
                    File(context.getExternalFilesDir(null), ATTENDANCE_DATA_FILE),
                    File(context.cacheDir, ATTENDANCE_DATA_FILE)
                )

                var targetFile: File? = null
                for (file in possiblePaths) {
                    android.util.Log.d("AttendanceWidget", "Checking path: ${file.absolutePath} exists=${file.exists()}")
                    if (file.exists()) {
                        targetFile = file
                        break
                    }
                }

                if (targetFile != null) {
                    val json = JSONObject(targetFile.readText())
                    subjectName = json.optString("subjectName", subjectName)
                    attended = json.optInt("attended", 0)
                    total = json.optInt("total", 0)
                    percentage = json.optInt("percentage", 0)
                    statusColorStr = json.optString("statusColor", "grey")
                    canMissText = json.optString("canMissText", canMissText)
                    streakDays = json.optInt("streakDays", 0)
                    android.util.Log.i("AttendanceWidget", "Loaded data from: ${targetFile.absolutePath}")
                } else {
                    android.util.Log.w("AttendanceWidget", "Data file not found in any path")
                }
            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "JSON read failed", e)
            }

            try {
                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                views.setTextViewText(R.id.attendance_widget_subject, subjectName)
                views.setTextViewText(R.id.attendance_widget_ratio, "$attended / $total")
                views.setTextViewText(R.id.attendance_widget_percent, "$percentage%")

                // FIXED: Always show one ring. Default to green for 0%
                val showGreen = percentage >= 75 || percentage == 0
                val showOrange = percentage in 60..74
                val showRed = percentage in 1..59

                views.setProgressBar(R.id.attendance_widget_progress_green, 100, percentage.coerceIn(0, 100), false)
                views.setProgressBar(R.id.attendance_widget_progress_orange, 100, percentage.coerceIn(0, 100), false)
                views.setProgressBar(R.id.attendance_widget_progress_red, 100, percentage.coerceIn(0, 100), false)

                views.setViewVisibility(R.id.attendance_widget_progress_green, if (showGreen) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.attendance_widget_progress_orange, if (showOrange) View.VISIBLE else View.GONE)
                views.setViewVisibility(R.id.attendance_widget_progress_red, if (showRed) View.VISIBLE else View.GONE)

                val statusColorHex = when {
                    percentage >= 75 -> "#FF4CAF50"
                    percentage >= 60 -> "#FFFF9800"
                    percentage > 0 -> "#FFF44336"
                    else -> "#FF888888"
                }

                views.setTextViewText(R.id.attendance_widget_status, canMissText)
                views.setTextColor(R.id.attendance_widget_status, Color.parseColor("#FFFFFF"))

                val bgColorHex = when {
                    percentage >= 75 -> "#304CAF50"
                    percentage >= 60 -> "#30FF9800"
                    percentage > 0 -> "#30F44336"
                    else -> "#30888888"
                }
                views.setInt(R.id.attendance_widget_status, "setBackgroundColor", Color.parseColor(bgColorHex))

                if (streakDays > 0) {
                    views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                    views.setTextViewText(R.id.attendance_widget_streak_text, "$streakDays day streak")
                } else {
                    views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                }

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
        super.onUpdate(context, appWidgetManager, appWidgetIds)
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
