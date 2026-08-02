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
import es.antonborri.home_widget.HomeWidgetPlugin

class AttendanceWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val KEY_SUBJECT_COUNT = "attendance_subject_count"
        private const val KEY_PREFIX_SUBJECT_NAME = "attendance_subject_name_"
        private const val KEY_PREFIX_SUBJECT_PERCENT = "attendance_subject_percent_"
        private const val KEY_PREFIX_SUBJECT_PRESENT = "attendance_subject_present_"
        private const val KEY_PREFIX_SUBJECT_ABSENT = "attendance_subject_absent_"
        private const val KEY_PREFIX_SUBJECT_LATE = "attendance_subject_late_"
        private const val KEY_PREFIX_SUBJECT_EXCUSED = "attendance_subject_excused_"
        private const val KEY_PREFIX_SUBJECT_TOTAL = "attendance_subject_total_"
        private const val KEY_PREFIX_SUBJECT_COLOR = "attendance_subject_color_"
        private const val KEY_PREFIX_SUBJECT_STATUS = "attendance_subject_status_"
        private const val KEY_PREFIX_SUBJECT_STREAK = "attendance_subject_streak_"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val subjectCount = widgetData.getInt(KEY_SUBJECT_COUNT, 0)

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                if (subjectCount == 0) {
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "No Subjects")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "Tap to add")

                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        launchIntent.putExtra("route", "/attendance")
                        val pendingIntent = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_empty_state, pendingIntent)
                    }

                } else {
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    val name = widgetData.getString(KEY_PREFIX_SUBJECT_NAME + "0", "Subject") ?: "Subject"
                    val percent = widgetData.getInt(KEY_PREFIX_SUBJECT_PERCENT + "0", 0)
                    val present = widgetData.getInt(KEY_PREFIX_SUBJECT_PRESENT + "0", 0)
                    val absent = widgetData.getInt(KEY_PREFIX_SUBJECT_ABSENT + "0", 0)
                    val late = widgetData.getInt(KEY_PREFIX_SUBJECT_LATE + "0", 0)
                    val excused = widgetData.getInt(KEY_PREFIX_SUBJECT_EXCUSED + "0", 0)
                    val total = widgetData.getInt(KEY_PREFIX_SUBJECT_TOTAL + "0", 0)
                    val colorHex = widgetData.getString(KEY_PREFIX_SUBJECT_COLOR + "0", "#4CAF50") ?: "#4CAF50"
                    val statusText = widgetData.getString(KEY_PREFIX_SUBJECT_STATUS + "0", "No data") ?: "No data"
                    val streak = widgetData.getInt(KEY_PREFIX_SUBJECT_STREAK + "0", 0)

                    val percentColor = when {
                        percent >= 75 -> Color.parseColor("#81C784")
                        percent >= 60 -> Color.parseColor("#FFB74D")
                        else -> Color.parseColor("#E57373")
                    }

                    views.setTextViewText(R.id.attendance_widget_subject, name)
                    views.setTextColor(R.id.attendance_widget_subject, Color.WHITE)

                    views.setTextViewText(R.id.attendance_widget_percent, "$percent%")
                    views.setTextColor(R.id.attendance_widget_percent, percentColor)

                    val effectiveTotal = total - excused
                    views.setTextViewText(R.id.attendance_widget_ratio, "$present / $effectiveTotal sessions")
                    views.setTextColor(R.id.attendance_widget_ratio, Color.parseColor("#B0FFFFFF"))

                    views.setTextViewText(R.id.chip_present, "P:$present")
                    views.setTextViewText(R.id.chip_absent, "A:$absent")
                    views.setTextViewText(R.id.chip_late, "L:$late")
                    views.setTextViewText(R.id.chip_excused, "E:$excused")

                    views.setTextViewText(R.id.attendance_widget_status, statusText)
                    views.setTextColor(R.id.attendance_widget_status, Color.WHITE)

                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // SAFE: Use setInt with "setBackgroundColor" for the dot's background
                    // This works because we use a View with android:background in XML
                    val subjectColor = try {
                        Color.parseColor(colorHex)
                    } catch (e: Exception) {
                        Color.parseColor("#4CAF50")
                    }
                    // For the colored left border, we use the dot's background
                    views.setInt(R.id.attendance_widget_subject_dot, "setBackgroundColor", subjectColor)

                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        launchIntent.putExtra("route", "/attendance")
                        val pendingIntent = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_content, pendingIntent)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed for widget $widgetId", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.attendance_widget_layout)
                    fallbackViews.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    fallbackViews.setViewVisibility(R.id.attendance_widget_content, View.GONE)
                    fallbackViews.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    fallbackViews.setTextViewText(R.id.attendance_widget_empty_subtitle, "Tap to open")
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (e2: Exception) {
                    android.util.Log.e("AttendanceWidget", "Fallback also failed", e2)
                }
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
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
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
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }
}
