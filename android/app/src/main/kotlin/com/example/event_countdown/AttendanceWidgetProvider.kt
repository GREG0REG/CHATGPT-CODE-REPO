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

        private const val MAX_SUBJECTS = 3

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
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "Tap to add subjects")

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

                    var anyStreak = false
                    var maxStreak = 0
                    for (i in 0 until subjectCount.coerceAtMost(MAX_SUBJECTS)) {
                        val streak = widgetData.getInt(KEY_PREFIX_SUBJECT_STREAK + "$i", 0)
                        if (streak > maxStreak) maxStreak = streak
                        if (streak > 0) anyStreak = true
                    }

                    if (anyStreak && maxStreak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$maxStreak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)
                    for (i in 0 until MAX_SUBJECTS) {
                        val rowVisible = i < displayCount

                        val rowId = when (i) {
                            0 -> R.id.subject_row_0
                            1 -> R.id.subject_row_1
                            2 -> R.id.subject_row_2
                            else -> 0
                        }
                        val chipsId = when (i) {
                            0 -> R.id.chips_row_0
                            1 -> R.id.chips_row_1
                            2 -> R.id.chips_row_2
                            else -> 0
                        }
                        val statusId = when (i) {
                            0 -> R.id.status_0
                            1 -> R.id.status_1
                            2 -> R.id.status_2
                            else -> 0
                        }
                        val dividerId = when (i) {
                            0 -> R.id.divider_0
                            1 -> R.id.divider_1
                            else -> 0
                        }

                        if (rowId != 0) views.setViewVisibility(rowId, if (rowVisible) View.VISIBLE else View.GONE)
                        if (chipsId != 0) views.setViewVisibility(chipsId, if (rowVisible) View.VISIBLE else View.GONE)
                        if (statusId != 0) views.setViewVisibility(statusId, if (rowVisible) View.VISIBLE else View.GONE)
                        if (dividerId != 0) views.setViewVisibility(dividerId, if (rowVisible && i < displayCount - 1) View.VISIBLE else View.GONE)

                        if (rowVisible) {
                            val name = widgetData.getString(KEY_PREFIX_SUBJECT_NAME + "$i", "Subject") ?: "Subject"
                            val percent = widgetData.getInt(KEY_PREFIX_SUBJECT_PERCENT + "$i", 0)
                            val present = widgetData.getInt(KEY_PREFIX_SUBJECT_PRESENT + "$i", 0)
                            val absent = widgetData.getInt(KEY_PREFIX_SUBJECT_ABSENT + "$i", 0)
                            val late = widgetData.getInt(KEY_PREFIX_SUBJECT_LATE + "$i", 0)
                            val excused = widgetData.getInt(KEY_PREFIX_SUBJECT_EXCUSED + "$i", 0)
                            val total = widgetData.getInt(KEY_PREFIX_SUBJECT_TOTAL + "$i", 0)
                            val colorHex = widgetData.getString(KEY_PREFIX_SUBJECT_COLOR + "$i", "#4CAF50") ?: "#4CAF50"
                            val statusText = widgetData.getString(KEY_PREFIX_SUBJECT_STATUS + "$i", "No data") ?: "No data"

                            val percentColor = when {
                                percent >= 75 -> Color.parseColor("#81C784")
                                percent >= 60 -> Color.parseColor("#FFB74D")
                                else -> Color.parseColor("#E57373")
                            }

                            val effectiveTotal = total - excused

                            val nameId = when (i) { 0 -> R.id.name_0; 1 -> R.id.name_1; 2 -> R.id.name_2; else -> 0 }
                            val pctId = when (i) { 0 -> R.id.pct_0; 1 -> R.id.pct_1; 2 -> R.id.pct_2; else -> 0 }
                            val ratioId = when (i) { 0 -> R.id.ratio_0; 1 -> R.id.ratio_1; 2 -> R.id.ratio_2; else -> 0 }
                            val dotId = when (i) { 0 -> R.id.dot_0; 1 -> R.id.dot_1; 2 -> R.id.dot_2; else -> 0 }
                            val pId = when (i) { 0 -> R.id.p0; 1 -> R.id.p1; 2 -> R.id.p2; else -> 0 }
                            val aId = when (i) { 0 -> R.id.a0; 1 -> R.id.a1; 2 -> R.id.a2; else -> 0 }
                            val lId = when (i) { 0 -> R.id.l0; 1 -> R.id.l1; 2 -> R.id.l2; else -> 0 }
                            val eId = when (i) { 0 -> R.id.e0; 1 -> R.id.e1; 2 -> R.id.e2; else -> 0 }

                            if (nameId != 0) views.setTextViewText(nameId, name)
                            if (pctId != 0) {
                                views.setTextViewText(pctId, "$percent%")
                                views.setTextColor(pctId, percentColor)
                            }
                            if (ratioId != 0) {
                                views.setTextViewText(ratioId, "$present / $effectiveTotal sessions")
                                views.setTextColor(ratioId, Color.parseColor("#B0FFFFFF"))
                            }
                            if (dotId != 0) {
                                val subjectColor = try { Color.parseColor(colorHex) } catch (e: Exception) { Color.parseColor("#4CAF50") }
                                views.setInt(dotId, "setBackgroundColor", subjectColor)
                            }
                            if (pId != 0) views.setTextViewText(pId, "P:$present")
                            if (aId != 0) views.setTextViewText(aId, "A:$absent")
                            if (lId != 0) views.setTextViewText(lId, "L:$late")
                            if (eId != 0) views.setTextViewText(eId, "E:$excused")
                            if (statusId != 0) {
                                views.setTextViewText(statusId, statusText)
                                views.setTextColor(statusId, Color.WHITE)
                            }
                        }
                    }

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
