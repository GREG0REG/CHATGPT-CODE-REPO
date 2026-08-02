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
        private const val KEY_PREFIX_NAME = "attendance_subject_name_"
        private const val KEY_PREFIX_PERCENT = "attendance_subject_percent_"
        private const val KEY_PREFIX_PRESENT = "attendance_subject_present_"
        private const val KEY_PREFIX_ABSENT = "attendance_subject_absent_"
        private const val KEY_PREFIX_LATE = "attendance_subject_late_"
        private const val KEY_PREFIX_EXCUSED = "attendance_subject_excused_"
        private const val KEY_PREFIX_TOTAL = "attendance_subject_total_"
        private const val KEY_PREFIX_COLOR = "attendance_subject_color_"
        private const val KEY_PREFIX_STATUS = "attendance_subject_status_"
        private const val KEY_PREFIX_STREAK = "attendance_subject_streak_"

        private fun getPercentColor(percent: Int): Int {
            return when {
                percent >= 75 -> Color.parseColor("#4CAF50")
                percent >= 60 -> Color.parseColor("#FF9800")
                else -> Color.parseColor("#F44336")
            }
        }

        private fun safeColor(hex: String?, fallback: String = "#4CAF50"): Int {
            return try {
                Color.parseColor(hex ?: fallback)
            } catch (e: Exception) {
                Color.parseColor(fallback)
            }
        }

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
                    // Empty state
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "No Subjects")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "0 / 0")
                    views.setTextViewText(R.id.attendance_widget_empty_cta, "Add subjects to track attendance")

                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        val pi = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_empty_state, pi)
                    }

                } else {
                    // Content state
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    // Subject 0 (large)
                    val name0 = widgetData.getString(KEY_PREFIX_NAME + "0", "Subject") ?: "Subject"
                    val percent0 = widgetData.getInt(KEY_PREFIX_PERCENT + "0", 0)
                    val present0 = widgetData.getInt(KEY_PREFIX_PRESENT + "0", 0)
                    val absent0 = widgetData.getInt(KEY_PREFIX_ABSENT + "0", 0)
                    val late0 = widgetData.getInt(KEY_PREFIX_LATE + "0", 0)
                    val excused0 = widgetData.getInt(KEY_PREFIX_EXCUSED + "0", 0)
                    val total0 = widgetData.getInt(KEY_PREFIX_TOTAL + "0", 0)
                    val color0 = widgetData.getString(KEY_PREFIX_COLOR + "0", "#4CAF50") ?: "#4CAF50"
                    val status0 = widgetData.getString(KEY_PREFIX_STATUS + "0", "No data") ?: "No data"
                    val streak0 = widgetData.getInt(KEY_PREFIX_STREAK + "0", 0)

                    val effectiveTotal0 = total0 - excused0

                    views.setTextViewText(R.id.attendance_widget_subject, name0)
                    views.setTextColor(R.id.attendance_widget_subject, Color.WHITE)

                    views.setTextViewText(R.id.attendance_widget_percent, "$percent0%")
                    views.setTextColor(R.id.attendance_widget_percent, getPercentColor(percent0))

                    views.setTextViewText(R.id.attendance_widget_ratio, "$present0 / $effectiveTotal0")
                    views.setTextColor(R.id.attendance_widget_ratio, Color.parseColor("#CCFFFFFF"))

                    views.setTextViewText(R.id.chip_present, "P:$present0")
                    views.setTextViewText(R.id.chip_absent, "A:$absent0")
                    views.setTextViewText(R.id.chip_late, "L:$late0")
                    views.setTextViewText(R.id.chip_excused, "E:$excused0")

                    views.setTextViewText(R.id.attendance_widget_status, status0)
                    views.setTextColor(R.id.attendance_widget_status, Color.WHITE)

                    views.setTextColor(R.id.attendance_widget_subject_dot, safeColor(color0))

                    // Streak chip
                    if (streak0 > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak0")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // Subject 1
                    val hasSubject1 = subjectCount > 1
                    views.setViewVisibility(R.id.subject_row_1, if (hasSubject1) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.divider_0, if (hasSubject1) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.status_1, if (hasSubject1) View.VISIBLE else View.GONE)

                    if (hasSubject1) {
                        val name1 = widgetData.getString(KEY_PREFIX_NAME + "1", "Subject") ?: "Subject"
                        val percent1 = widgetData.getInt(KEY_PREFIX_PERCENT + "1", 0)
                        val present1 = widgetData.getInt(KEY_PREFIX_PRESENT + "1", 0)
                        val absent1 = widgetData.getInt(KEY_PREFIX_ABSENT + "1", 0)
                        val late1 = widgetData.getInt(KEY_PREFIX_LATE + "1", 0)
                        val excused1 = widgetData.getInt(KEY_PREFIX_EXCUSED + "1", 0)
                        val total1 = widgetData.getInt(KEY_PREFIX_TOTAL + "1", 0)
                        val color1 = widgetData.getString(KEY_PREFIX_COLOR + "1", "#4CAF50") ?: "#4CAF50"
                        val status1 = widgetData.getString(KEY_PREFIX_STATUS + "1", "No data") ?: "No data"

                        val effectiveTotal1 = total1 - excused1

                        views.setTextViewText(R.id.name_1, name1)
                        views.setTextColor(R.id.name_1, Color.WHITE)
                        views.setTextViewText(R.id.pct_1, "$percent1%")
                        views.setTextColor(R.id.pct_1, getPercentColor(percent1))
                        views.setTextViewText(R.id.ratio_1, "$present1 / $effectiveTotal1")
                        views.setTextColor(R.id.ratio_1, Color.parseColor("#CCFFFFFF"))
                        views.setTextColor(R.id.dot_1, safeColor(color1))
                        views.setTextViewText(R.id.p1, "P:$present1")
                        views.setTextViewText(R.id.a1, "A:$absent1")
                        views.setTextViewText(R.id.l1, "L:$late1")
                        views.setTextViewText(R.id.e1, "E:$excused1")
                        views.setTextViewText(R.id.status_1, status1)
                        views.setTextColor(R.id.status_1, Color.WHITE)
                    }

                    // Subject 2
                    val hasSubject2 = subjectCount > 2
                    views.setViewVisibility(R.id.subject_row_2, if (hasSubject2) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.divider_1, if (hasSubject2) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.status_2, if (hasSubject2) View.VISIBLE else View.GONE)

                    if (hasSubject2) {
                        val name2 = widgetData.getString(KEY_PREFIX_NAME + "2", "Subject") ?: "Subject"
                        val percent2 = widgetData.getInt(KEY_PREFIX_PERCENT + "2", 0)
                        val present2 = widgetData.getInt(KEY_PREFIX_PRESENT + "2", 0)
                        val absent2 = widgetData.getInt(KEY_PREFIX_ABSENT + "2", 0)
                        val late2 = widgetData.getInt(KEY_PREFIX_LATE + "2", 0)
                        val excused2 = widgetData.getInt(KEY_PREFIX_EXCUSED + "2", 0)
                        val total2 = widgetData.getInt(KEY_PREFIX_TOTAL + "2", 0)
                        val color2 = widgetData.getString(KEY_PREFIX_COLOR + "2", "#4CAF50") ?: "#4CAF50"
                        val status2 = widgetData.getString(KEY_PREFIX_STATUS + "2", "No data") ?: "No data"

                        val effectiveTotal2 = total2 - excused2

                        views.setTextViewText(R.id.name_2, name2)
                        views.setTextColor(R.id.name_2, Color.WHITE)
                        views.setTextViewText(R.id.pct_2, "$percent2%")
                        views.setTextColor(R.id.pct_2, getPercentColor(percent2))
                        views.setTextViewText(R.id.ratio_2, "$present2 / $effectiveTotal2")
                        views.setTextColor(R.id.ratio_2, Color.parseColor("#CCFFFFFF"))
                        views.setTextColor(R.id.dot_2, safeColor(color2))
                        views.setTextViewText(R.id.p2, "P:$present2")
                        views.setTextViewText(R.id.a2, "A:$absent2")
                        views.setTextViewText(R.id.l2, "L:$late2")
                        views.setTextViewText(R.id.e2, "E:$excused2")
                        views.setTextViewText(R.id.status_2, status2)
                        views.setTextColor(R.id.status_2, Color.WHITE)
                    }

                    // Subject 3
                    val hasSubject3 = subjectCount > 3
                    views.setViewVisibility(R.id.subject_row_3, if (hasSubject3) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.divider_2, if (hasSubject3) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.status_3, if (hasSubject3) View.VISIBLE else View.GONE)

                    if (hasSubject3) {
                        val name3 = widgetData.getString(KEY_PREFIX_NAME + "3", "Subject") ?: "Subject"
                        val percent3 = widgetData.getInt(KEY_PREFIX_PERCENT + "3", 0)
                        val present3 = widgetData.getInt(KEY_PREFIX_PRESENT + "3", 0)
                        val absent3 = widgetData.getInt(KEY_PREFIX_ABSENT + "3", 0)
                        val late3 = widgetData.getInt(KEY_PREFIX_LATE + "3", 0)
                        val excused3 = widgetData.getInt(KEY_PREFIX_EXCUSED + "3", 0)
                        val total3 = widgetData.getInt(KEY_PREFIX_TOTAL + "3", 0)
                        val color3 = widgetData.getString(KEY_PREFIX_COLOR + "3", "#4CAF50") ?: "#4CAF50"
                        val status3 = widgetData.getString(KEY_PREFIX_STATUS + "3", "No data") ?: "No data"

                        val effectiveTotal3 = total3 - excused3

                        views.setTextViewText(R.id.name_3, name3)
                        views.setTextColor(R.id.name_3, Color.WHITE)
                        views.setTextViewText(R.id.pct_3, "$percent3%")
                        views.setTextColor(R.id.pct_3, getPercentColor(percent3))
                        views.setTextViewText(R.id.ratio_3, "$present3 / $effectiveTotal3")
                        views.setTextColor(R.id.ratio_3, Color.parseColor("#CCFFFFFF"))
                        views.setTextColor(R.id.dot_3, safeColor(color3))
                        views.setTextViewText(R.id.p3, "P:$present3")
                        views.setTextViewText(R.id.a3, "A:$absent3")
                        views.setTextViewText(R.id.l3, "L:$late3")
                        views.setTextViewText(R.id.e3, "E:$excused3")
                        views.setTextViewText(R.id.status_3, status3)
                        views.setTextColor(R.id.status_3, Color.WHITE)
                    }

                    // Click to open
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        launchIntent.putExtra("route", "/attendance")
                        val pi = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_content, pi)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed for widget $widgetId", e)
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.attendance_widget_layout)
                    fallback.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    fallback.setViewVisibility(R.id.attendance_widget_content, View.GONE)
                    fallback.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    fallback.setTextViewText(R.id.attendance_widget_empty_subtitle, "Tap to open")
                    fallback.setTextViewText(R.id.attendance_widget_empty_cta, "Track your attendance")
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (e2: Exception) {
                    android.util.Log.e("AttendanceWidget", "Fallback also failed", e2)
                }
            }
        }

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, AttendanceWidgetProvider::class.java)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                android.util.Log.i("AttendanceWidget", "Updating ${widgetIds.size} widgets")
                for (widgetId in widgetIds) {
                    updateWidgetDirectly(context, appWidgetManager, widgetId)
                }
            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "updateAllWidgets failed", e)
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
